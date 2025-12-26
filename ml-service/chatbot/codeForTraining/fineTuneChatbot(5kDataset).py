#!/usr/bin/env python3
"""
QLoRA fine-tuning script for Qwen2-1.5B-Instruct
Designed for ~12GB GPU systems. Produces logs, checkpoints, validation, plots.

Usage:
    python qlora_finetune_qwen2.py --data_path final_dataset.jsonl --output_dir outputs/qwen2_qlora_run

"""

import os
import json
import math
import random
import argparse
import platform
from datetime import datetime
from pathlib import Path
from typing import Dict, List

import torch
import numpy as np

from transformers import EarlyStoppingCallback
from rouge_score import rouge_scorer
from nltk.translate.bleu_score import sentence_bleu, SmoothingFunction

# Transformers / bitsandbytes / peft
from transformers import (
    AutoTokenizer,
    AutoConfig,
    AutoModelForCausalLM,
    Trainer,
    TrainingArguments,
    DataCollatorForLanguageModeling,
)
try:
    import bitsandbytes as bnb
except Exception:
    bnb = None

try:
    from peft import get_peft_model, LoraConfig, TaskType, prepare_model_for_kbit_training
except Exception:
    raise ImportError("Please install 'peft' (pip install peft).")

# Datasets
from datasets import load_dataset

# Logging & plotting
from torch.utils.tensorboard import SummaryWriter
import matplotlib.pyplot as plt

# ---------- CONFIG (edit if you want) ----------
DEFAULT_CONFIG = {
    "model_name_or_path": "Qwen/Qwen2.5-1.5B-Instruct",  # adjust if your model path differs
    "data_path": r"C:\Haroon-Data\code\fyp\application\LegalMate.pk\docs\dataForTaining-chatBot\updatedWork\finalFile\final_dataset.jsonl",
    "output_dir": r"C:\Haroon-Data\code\fyp\application\LegalMate.pk\ml-service\chatbot\ChatBot-qwen2(15kDataset)\qwen2_qlora_run",
    "seed": 42,
    "total_train_samples": 5000,  # informational
    "validation_split_ratio": 0.10,
    # QLoRA & training hyperparameters
    "num_train_epochs": 2,
    "learning_rate": 2e-5,
    "micro_batch_size": 1,    # per-GPU micro batch
    "gradient_accumulation_steps": 16,  # micro_batch * accum = effective batch
    "weight_decay": 0.0,
    "lr_scheduler_type": "cosine",
    "warmup_ratio": 0.1,
    "max_seq_length": 2048,
    # LoRA
    "lora_r": 16,
    "lora_alpha": 32,
    "lora_dropout": 0.1,
    # Save / logging
    "logging_steps": 20,
    "eval_steps": 200,
    "save_steps": 200,
    "save_total_limit": 5,
    # Generation config for sample eval
    "generation_max_new_tokens": 256,
    "generation_temperature": 0.2,
    "generation_top_p": 0.95,
    # Misc
    "use_wandb": False,   # set True if you have wandb configured
    "report_to": ["tensorboard"],  # or ["wandb","tensorboard"]
    "device_map": "auto",
    "load_in_4bit": True,
    "bnb_4bit_use_double_quant": True,
    "bnb_4bit_quant_type": "nf4",
    "resume_from_checkpoint": None,  # path to checkpoint to resume from, or None
}
# ------------------------------------------------

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data_path", type=str, default=DEFAULT_CONFIG["data_path"])
    parser.add_argument("--output_dir", type=str, default=DEFAULT_CONFIG["output_dir"])
    parser.add_argument("--config_json", type=str, default=None,
                        help="Optional JSON file with configuration to override defaults.")
    return parser.parse_args()

def save_json(obj, path):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, indent=2, ensure_ascii=False)

def set_seed(seed: int):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)

def read_jsonl(path: str) -> List[Dict]:
    out = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            if line.strip():
                out.append(json.loads(line))
    return out

def to_text(example: dict) -> str:
    def normalize(x):
        if x is None:
            return ""
        if isinstance(x, str):
            return x.strip()
        if isinstance(x, dict):
            # try common keys
            for k in ["answer", "text", "response", "content"]:
                if k in x and isinstance(x[k], str):
                    return x[k].strip()
            return json.dumps(x, ensure_ascii=False)
        if isinstance(x, list):
            return " ".join([normalize(i) for i in x])
        return str(x)

    instruction = normalize(example.get("instruction"))
    input_text = normalize(example.get("input"))
    output_text = normalize(example.get("output"))

    if instruction and input_text:
        return (
            "### Instruction:\n"
            f"{instruction}\n\n"
            "### Input:\n"
            f"{input_text}\n\n"
            "### Response:\n"
            f"{output_text}"
        )
    elif instruction:
        return (
            "### Instruction:\n"
            f"{instruction}\n\n"
            "### Response:\n"
            f"{output_text}"
        )
    else:
        # fallback: stringify whole sample
        return json.dumps(example, ensure_ascii=False)

def preprocess_and_tokenize(dataset_list: List[Dict], tokenizer, max_length: int):
    texts = [to_text(x) for x in dataset_list]
    # Tokenize with truncation and padding disabled (we'll pad in data collator)
    tokenized = tokenizer(texts, truncation=True, max_length=max_length, return_tensors=None)
    # For causal LM, we want labels identical to input_ids
    examples = []
    for i, input_ids in enumerate(tokenized["input_ids"]):
        examples.append({
            "input_ids": input_ids,
            "attention_mask": tokenized["attention_mask"][i],
            "labels": input_ids.copy()
        })
    return examples

def collate_fn(batch, tokenizer, max_length):
    """
    Pads and converts to tensors. Uses tokenizer.pad.
    """
    input_ids = [item["input_ids"] for item in batch]
    attention_masks = [item["attention_mask"] for item in batch]
    labels = [item["labels"] for item in batch]
    batch_enc = tokenizer.pad(
        {"input_ids": input_ids, "attention_mask": attention_masks, "labels": labels},
        padding=True,
        max_length=max_length,
        return_tensors="pt"
    )
    # For causal LM, ensure -100 is used for padding tokens in labels
    batch_enc["labels"][batch_enc["labels"] == tokenizer.pad_token_id] = -100
    return batch_enc

def get_hardware_info():
    info = {
        "platform": platform.platform(),
        "python_version": platform.python_version(),
        "torch_version": torch.__version__,
        "cuda_available": torch.cuda.is_available(),
        "cuda_device_count": torch.cuda.device_count(),
    }
    if torch.cuda.is_available():
        info["cuda_device_name"] = torch.cuda.get_device_name(0)
        info["cuda_memory_total_GB"] = round(torch.cuda.get_device_properties(0).total_memory / (1024**3), 2)
    return info

def compute_exact_match(pred, label):
    return float(pred.strip().lower() == label.strip().lower())

def compute_bleu(pred, label):
    smoothie = SmoothingFunction().method4
    return sentence_bleu([label.split()], pred.split(), smoothing_function=smoothie)

rouge = rouge_scorer.RougeScorer(['rougeL'], use_stemmer=True)
def compute_rouge(pred, label):
    try:
        score = rouge.score(label, pred)
        return score['rougeL'].fmeasure
    except:
        return 0.0

def compute_all_metrics(pred, label):
    return {
        "exact_match": compute_exact_match(pred, label),
        "bleu": compute_bleu(pred, label),
        "rougeL": compute_rouge(pred, label)
    }
from transformers import TrainerCallback

class MetricsCallback(TrainerCallback):
    def __init__(self, tokenizer, config, output_dir):
        self.tokenizer = tokenizer
        self.config = config
        self.output_dir = output_dir
        os.makedirs(os.path.join(output_dir, "metrics"), exist_ok=True)
        self.results = []

    def on_evaluate(self, args, state, control, model=None, **kwargs):
        eval_dataset = kwargs.get("eval_dataset")
        if eval_dataset is None:
            return

        sample_count = min(50, len(eval_dataset))  # evaluate on 50 validation examples
        indices = random.sample(range(len(eval_dataset)), sample_count)
        metrics = {"exact_match": [], "bleu": [], "rougeL": []}

        model.eval()
        if torch.cuda.is_available():
            model.to("cuda")

        for idx in indices:
            batch = eval_dataset[idx]
            input_ids = batch["input_ids"]
            label_ids = batch["labels"]

            prompt = self.tokenizer.decode([x for x in input_ids if x != self.tokenizer.pad_token_id])
            label_text = self.tokenizer.decode([x for x in label_ids if x != -100])

            # Generate model output
            inputs = self.tokenizer(prompt, return_tensors="pt", truncation=True, max_length=self.config["max_seq_length"])
            if torch.cuda.is_available():
                inputs = {k:v.to("cuda") for k,v in inputs.items()}

            output_tokens = model.generate(
                **inputs,
                max_new_tokens=256,
                temperature=0.2,
                top_p=0.95,
                do_sample=True
            )
            pred_text = self.tokenizer.decode(output_tokens[0], skip_special_tokens=True)

            m = compute_all_metrics(pred_text, label_text)
            for k, v in m.items():
                metrics[k].append(v)

        # average
        final_metrics = {k: float(np.mean(v)) for k, v in metrics.items()}
        step = state.global_step

        # save as json
        out_path = os.path.join(self.output_dir, "metrics", f"metrics_step_{step}.json")
        save_json(final_metrics, out_path)

        print("\n=== EVALUATION METRICS ===")
        print(f"Step {step}:", final_metrics)
        print("==========================\n")

        return final_metrics

def main():
    args = parse_args()

    # -------------------- load/override config --------------------
    config = DEFAULT_CONFIG.copy()
    if args.config_json:
        with open(args.config_json, "r", encoding="utf-8") as f:
            override = json.load(f)
        config.update(override)

    # override from CLI
    config["data_path"] = args.data_path
    config["output_dir"] = args.output_dir

    os.makedirs(config["output_dir"], exist_ok=True)

    # Save used config
    save_json(config, os.path.join(config["output_dir"], "run_config.json"))

    # -------------------- environment / seed --------------------
    set_seed(config["seed"])

    # record environment/hardware
    hw = get_hardware_info()
    save_json(hw, os.path.join(config["output_dir"], "hardware_info.json"))

    # -------------------- load dataset --------------------
    print("Loading dataset:", config["data_path"])
    raw = read_jsonl(config["data_path"])
    total = len(raw)
    print(f"Total raw samples read: {total}")

    # split into train / validation
    val_ratio = config["validation_split_ratio"]
    val_count = max(1, int(total * val_ratio))
    random.shuffle(raw)
    val_examples = raw[:val_count]
    train_examples = raw[val_count:]
    print(f"Train samples: {len(train_examples)}, Validation samples: {len(val_examples)}")
    save_json({"total": total, "train": len(train_examples), "validation": len(val_examples)},
              os.path.join(config["output_dir"], "dataset_stats.json"))

    # -------------------- tokenizer --------------------
    print("Loading tokenizer...")
    tokenizer = AutoTokenizer.from_pretrained(config["model_name_or_path"], use_fast=True)
    # ensure pad token exists
    if tokenizer.pad_token is None:
        tokenizer.add_special_tokens({"pad_token": "<|pad|>"})

    # -------------------- preprocessing --------------------
    print("Tokenizing / preprocessing (may take a bit)...")
    train_processed = preprocess_and_tokenize(train_examples, tokenizer, config["max_seq_length"])
    val_processed = preprocess_and_tokenize(val_examples, tokenizer, config["max_seq_length"])
    print("Prepared tokenized datasets: train:", len(train_processed), "val:", len(val_processed))

    # Convert to Hugging Face Dataset objects for Trainer
    # hf_train = load_dataset("json", data_files={"train": config["data_path"]}, split="train")
    # But we already tokenized above (keeps flexibility). We will use custom collate to handle tokenized lists instead.
    # Simpler: create custom datasets
    class ListDataset(torch.utils.data.Dataset):
        def __init__(self, examples):
            self.examples = examples
        def __len__(self):
            return len(self.examples)
        def __getitem__(self, idx):
            return self.examples[idx]

    train_dataset = ListDataset(train_processed)
    eval_dataset = ListDataset(val_processed)

    # -------------------- model loading (4-bit) --------------------
    print("Loading model in 4-bit (QLoRA) ... (this may take a minute)")
    # Use auto config + load_in_4bit arguments supported by Transformers + bitsandbytes
    kwargs = {}
    if config["load_in_4bit"] and bnb is not None:
        kwargs = {
            "load_in_4bit": True,
            "bnb_4bit_quant_type": config["bnb_4bit_quant_type"],
            "bnb_4bit_use_double_quant": config["bnb_4bit_use_double_quant"],
            "device_map": config["device_map"],
        }
    else:
        # fallback to fp16 with device_map auto
        kwargs = {"torch_dtype": torch.float16, "device_map": config["device_map"]}

    # The model might be on huggingface hub under different id; user should adjust model_name_or_path accordingly
    model = AutoModelForCausalLM.from_pretrained(
        config["model_name_or_path"],
        trust_remote_code=True,
        low_cpu_mem_usage=True,
        **kwargs,
    )

    # Prepare model for k-bit (PEFT recommendation)
    model = prepare_model_for_kbit_training(model)

    # -------------------- LoRA (PEFT) --------------------
    print("Applying LoRA adapters...")
    peft_config = LoraConfig(
        r=config["lora_r"],
        lora_alpha=config["lora_alpha"],
        target_modules=["q_proj", "v_proj", "k_proj", "o_proj", "gate_proj", "down_proj", "up_proj"],
        lora_dropout=config["lora_dropout"],
        bias="none",
        task_type=TaskType.CAUSAL_LM,
    )
    model = get_peft_model(model, peft_config)

    # Print number of trainable params
    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    total_params = sum(p.numel() for p in model.parameters())
    print(f"Trainable params: {trainable:,} / {total_params:,}")

    # -------------------- TrainingArguments / Trainer --------------------
    tb_log_dir = os.path.join(config["output_dir"], "tensorboard")
    os.makedirs(tb_log_dir, exist_ok=True)

    training_args = TrainingArguments(
        output_dir=config["output_dir"],
        per_device_train_batch_size=config["micro_batch_size"],
        per_device_eval_batch_size=config["micro_batch_size"],
        gradient_accumulation_steps=config["gradient_accumulation_steps"],
        num_train_epochs=config["num_train_epochs"],
        logging_steps=config["logging_steps"],
        eval_strategy="steps",
        eval_steps=config["eval_steps"],
        save_strategy="steps",
        save_steps=config["save_steps"],
        save_total_limit=config["save_total_limit"],
        dataloader_pin_memory=True,
        fp16=True if not config["load_in_4bit"] else False,
        disable_tqdm=False,
        report_to=config["report_to"],
        run_name=f"qlora_qwen2_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}",
        logging_dir=tb_log_dir,
        learning_rate=config["learning_rate"],
        weight_decay=config["weight_decay"],
        warmup_ratio=config["warmup_ratio"],
        lr_scheduler_type=config["lr_scheduler_type"],
        save_on_each_node=False,
        optim="paged_adamw_8bit",
        metric_for_best_model="eval_loss",
        greater_is_better=False,
        load_best_model_at_end=True,
    )

    # Data collator
    def hf_collator(examples):
        return collate_fn(examples, tokenizer, config["max_seq_length"])

    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=train_dataset,
        eval_dataset=eval_dataset,
        data_collator=hf_collator,
        tokenizer=tokenizer,
        callbacks=[EarlyStoppingCallback(early_stopping_patience=2), MetricsCallback(tokenizer, config, config["output_dir"])],
    )

    # -------------------- Summary writer (TensorBoard) --------------------
    writer = SummaryWriter(log_dir=tb_log_dir)

    # Save base metadata
    metadata = {
        "config": config,
        "hardware": hw,
        "trainable_params": int(trainable),
        "total_params": int(total_params),
        "date": datetime.utcnow().isoformat() + "Z",
        "dataset_counts": {"train": len(train_dataset), "eval": len(eval_dataset)}
    }
    save_json(metadata, os.path.join(config["output_dir"], "run_metadata.json"))

    # -------------------- Training (with checkpoint/resume) --------------------
    resume_ckpt = config.get("resume_from_checkpoint")
    print("Starting training...")
    checkpoint_dirs = [
    os.path.join(config["output_dir"], d)
    for d in os.listdir(config["output_dir"])
    if d.startswith("checkpoint-")
    ]

    if checkpoint_dirs:
        latest_checkpoint = sorted(checkpoint_dirs, key=lambda x: int(x.split("-")[-1]))[-1]
        print(f"Resuming from checkpoint: {latest_checkpoint}")
        trainer.train(resume_from_checkpoint=latest_checkpoint)
    else:
        print("No checkpoint found. Starting fresh training.")
        trainer.train()

    # -------------------- Save LoRA adapter and final artifacts --------------------
    print("Saving final LoRA adapter / state...")
    peft_save_dir = os.path.join(config["output_dir"], "lora_adapter")
    model.save_pretrained(peft_save_dir)
    tokenizer.save_pretrained(peft_save_dir)

    # Save trainer logs to file for post-processing
    log_history = trainer.state.log_history
    save_json(log_history, os.path.join(config["output_dir"], "trainer_log_history.json"))

    # -------------------- Extract training & eval loss history and plot --------------------
    train_steps = []
    train_losses = []
    eval_steps = []
    eval_losses = []

    for entry in log_history:
        if "loss" in entry:
            if "step" in entry:
                train_steps.append(entry["step"])
            train_losses.append(entry["loss"])
        if "eval_loss" in entry:
            eval_steps.append(entry.get("step", None))
            eval_losses.append(entry["eval_loss"])

    # Save arrays
    np.save(os.path.join(config["output_dir"], "train_steps.npy"), np.array(train_steps))
    np.save(os.path.join(config["output_dir"], "train_losses.npy"), np.array(train_losses))
    np.save(os.path.join(config["output_dir"], "eval_steps.npy"), np.array(eval_steps))
    np.save(os.path.join(config["output_dir"], "eval_losses.npy"), np.array(eval_losses))

    # Plot
    try:
        plt.figure(figsize=(8,5))
        if len(train_losses)>0:
            plt.plot(range(len(train_losses)), train_losses, label="train_loss")
        if len(eval_losses)>0:
            plt.plot(np.linspace(0, len(train_losses)-1, num=len(eval_losses)), eval_losses, label="eval_loss")
        plt.xlabel("Logging step index")
        plt.ylabel("Loss")
        plt.legend()
        plt.title("Training & Validation Loss")
        plt.grid(True)
        plt.tight_layout()
        plot_path = os.path.join(config["output_dir"], "loss_curve.png")
        plt.savefig(plot_path)
        print("Saved loss plot to", plot_path)
    except Exception as e:
        print("Could not plot loss curve:", e)

    # -------------------- Generate sample outputs on validation set and save --------------------
    gen_dir = os.path.join(config["output_dir"], "eval_generations")
    os.makedirs(gen_dir, exist_ok=True)
    n_samples_to_generate = min(10, len(eval_dataset))
    samples_for_gen = random.sample(val_examples, n_samples_to_generate)

    # Load model for generation (ensure device)
    model.eval()
    if torch.cuda.is_available():
        model.to("cuda")

    outputs = []
    for i, ex in enumerate(samples_for_gen):
        prompt_text = to_text(ex)
        inputs = tokenizer(prompt_text, return_tensors="pt", truncation=True, max_length=config["max_seq_length"])
        if torch.cuda.is_available():
            inputs = {k:v.to("cuda") for k,v in inputs.items()}
        gen_tokens = model.generate(
            **inputs,
            max_new_tokens=config["generation_max_new_tokens"],
            temperature=config["generation_temperature"],
            top_p=config["generation_top_p"],
            do_sample=True,
            eos_token_id=tokenizer.eos_token_id,
            pad_token_id=tokenizer.pad_token_id,
            # num_return_sequences=1
        )
        gen_text = tokenizer.decode(gen_tokens[0], skip_special_tokens=True)
        outputs.append({
            "prompt": prompt_text,
            "generated": gen_text,
            "reference": ex.get("output") or ex.get("labels") or ex.get("text", "")
        })

    save_json(outputs, os.path.join(gen_dir, "sample_generations.json"))

    print("Done. Artifacts saved to:", config["output_dir"])
    print("LoRA adapter directory:", peft_save_dir)
    print("You can inspect tensorboard logs in:", tb_log_dir)

if __name__ == "__main__":
    main()