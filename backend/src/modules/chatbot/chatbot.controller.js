import { chatBotApi, chatBotApiStream } from "./chatbot.service.js";
import ChatHistory from "./chathistory.model.js";
import mongoose from "mongoose";
import ChatSession from "./chatsession.model.js";
import { callOCRService } from "../ocr/ocr.service.js";

const _buildSessionTitle = (message = "") => {
  const normalized = String(message).replace(/\s+/g, " ").trim();
  if (!normalized) return "New Chat";
  return normalized.length > 48
    ? `${normalized.slice(0, 48).trim()}...`
    : normalized;
};

const _resolveChatSession = async (req, message, providedChatId) => {
  if (!req.user || req.user.is_guest) {
    return null;
  }

  if (providedChatId) {
    if (!mongoose.Types.ObjectId.isValid(providedChatId)) {
      const err = new Error("Invalid chatId");
      err.statusCode = 400;
      throw err;
    }

    const existingSession = await ChatSession.findOne({
      _id: providedChatId,
      user: req.user._id,
      is_guest: false,
    });

    if (!existingSession) {
      const err = new Error("Chat session not found");
      err.statusCode = 404;
      throw err;
    }

    return existingSession;
  }

  return ChatSession.create({
    user: req.user._id,
    title: _buildSessionTitle(message),
    is_guest: false,
    last_message_at: new Date(),
  });
};

const _updateSessionMetaIfNeeded = async (activeChatSession, message) => {
  if (!activeChatSession) return;

  const updateDoc = {
    $inc: { message_count: 1 },
    $set: {
      last_message_at: new Date(),
      updated_at: new Date(),
    },
  };

  if (activeChatSession.message_count === 0) {
    updateDoc.$set.title = _buildSessionTitle(message);
  }

  await ChatSession.updateOne({ _id: activeChatSession._id }, updateDoc);
};

const _persistChatTurn = async (
  req,
  message,
  reply,
  processingTime,
  activeChatSession
) => {
  if (!req.user) return;

  await ChatHistory.create({
    user: req.user._id,
    message: {
      text: message,
    },
    response: {
      text: reply,
    },
    session_id: activeChatSession?._id || null,
    is_guest: req.user.is_guest || false,
    processing_time_ms: processingTime,
  });

  await _updateSessionMetaIfNeeded(activeChatSession, message);
};

const _sendSseEvent = (res, payload) => {
  res.write(`data: ${JSON.stringify(payload)}\n\n`);
};

export const handleChat = async (req, res) => {
  try {
    const { message, chatId, stream: streamRequested } = req.body;
    const startTime = Date.now();

    if (!message || !String(message).trim()) {
      return res.status(400).json({
        success: false,
        error: "Message is required",
      });
    }

    // ── OCR pre-processing ──────────────────────────────────────────────────
    // If the client attached an image file, extract its text via the OCR
    // service and prepend it to the message before forwarding to the LLM.
    // The original (human-readable) message is kept for chat history.
    let finalMessage = String(message).trim();
    if (req.file) {
      // console.log(`[Chatbot] Image attached (${req.file.originalname}, ${req.file.size} bytes). Running OCR...`);
      const ocrResult = await callOCRService(
        req.file.buffer,
        req.file.originalname,
        req.file.mimetype
      );

      if (ocrResult.status === "success" && ocrResult.extracted_text) {
        const rawText = ocrResult.extracted_text.trim();
        const confidence = ocrResult.confidence_score ?? 0;
        // console.log(`[Chatbot] OCR succeeded. Confidence: ${(confidence * 100).toFixed(1)}%. Text length: ${rawText.length} chars.`);

        // Only use OCR text if confidence is sufficient (≥ 60%)
        // A null confidence score (some engines) is treated as acceptable.
        if (ocrResult.confidence_score === null || confidence >= 0.60) {
          finalMessage = `Document content:\n${rawText}\n\nUser question: ${finalMessage}`;
        } else {
          // console.warn(`[Chatbot] OCR confidence too low (${(confidence * 100).toFixed(1)}%). Proceeding without extracted text.`);
        }
      } else {
        // console.warn(`[Chatbot] OCR failed: ${ocrResult.error}. Proceeding with text-only message.`);
      }
    }
    // ────────────────────────────────────────────────────────────────────────

    const activeChatSession = await _resolveChatSession(req, message, chatId);

    const acceptsSse =
      (req.headers.accept || "").includes("text/event-stream") ||
      streamRequested === true ||
      streamRequested === "true";

    if (acceptsSse) {
      res.setHeader("Content-Type", "text/event-stream");
      res.setHeader("Cache-Control", "no-cache, no-transform");
      res.setHeader("Connection", "keep-alive");
      res.setHeader("X-Accel-Buffering", "no");
      if (typeof res.flushHeaders === "function") {
        res.flushHeaders();
      }

      _sendSseEvent(res, {
        type: "ready",
        chat_id: activeChatSession?._id || null,
      });

      let pythonStream = null;
      let streamEnded = false;
      let streamError = false;

      try {
        pythonStream = await chatBotApiStream(finalMessage);
        let fullReply = "";

        // Cleanup handler for when client disconnects
        const closeHandler = () => {
          // console.log(`[Chatbot] Client disconnected (session: ${activeChatSession?._id || 'guest'})`);
          if (pythonStream && typeof pythonStream.destroy === "function") {
            pythonStream.destroy();
          }
          streamEnded = true;
        };
        req.on("close", closeHandler);

        // Timeout handler to prevent hanging connections
        const timeoutHandle = setTimeout(() => {
          if (!streamEnded && pythonStream && typeof pythonStream.destroy === "function") {
            // console.warn(`[Chatbot] Stream timeout (>120s). Terminating. Session: ${activeChatSession?._id || 'guest'}`);
            pythonStream.destroy();
            if (!res.headersSent) {
              _sendSseEvent(res, {
                type: "error",
                error: "Response generation timed out. Please try again.",
              });
            }
            streamEnded = true;
            res.end();
          }
        }, 120000); // 120 second timeout

        // Data event with proper error state tracking
        pythonStream.on("data", (chunk) => {
          if (streamEnded || streamError) return;

          try {
            const textChunk = chunk.toString();
            if (!textChunk) return;
            fullReply += textChunk;
            _sendSseEvent(res, {
              type: "chunk",
              text: textChunk,
            });
          } catch (chunkError) {
            // console.error(`[Chatbot] Error processing chunk: ${chunkError.message}`);
            streamError = true;
          }
        });

        // ✅ FIX: End event with proper cleanup
        pythonStream.on("end", async () => {
          if (streamEnded) return; // Prevent duplicate processing
          streamEnded = true;
          clearTimeout(timeoutHandle);

          try {
            const finalReply =
              fullReply || "I couldn't generate a legal response at this time.";
            const processingTime = Date.now() - startTime;

            await _persistChatTurn(
              req,
              message,
              finalReply,
              processingTime,
              activeChatSession
            );

            const donePayload = {
              type: "done",
              chat_id: activeChatSession?._id || null,
              processing_time_ms: processingTime,
            };

            if (res.locals.guestCallInfo) {
              donePayload.guest_session = {
                remaining_calls: res.locals.guestCallInfo.remaining_calls,
                call_limit: res.locals.guestCallInfo.call_limit,
                warning: res.locals.guestCallInfo.is_guest_limit_warning
                  ? "You have limited API calls remaining. Please sign up for unlimited access."
                  : null,
              };
            }

            if (!res.writableEnded) {
              _sendSseEvent(res, donePayload);
              res.end();
            }
            // console.log(`[Chatbot] Stream ended. Session: ${activeChatSession?._id || 'guest'}`);
            req.off("close", closeHandler);
          } catch (persistError) {
            console.error(`[Chatbot] Persist error: ${persistError.message}`);
            if (!res.writableEnded) {
              _sendSseEvent(res, {
                type: "error",
                error: "Failed to finalize chatbot response",
              });
              res.end();
            }
            req.off("close", closeHandler);
          }
        });

        // Error event
        pythonStream.on("error", (streamError) => {
          streamError = true;
          clearTimeout(timeoutHandle);
          // console.error(`[Chatbot] Python stream error: ${streamError.message}`);
          // console.error(`[Chatbot] Error details:`, streamError);

          if (!streamEnded && !res.writableEnded) {
            _sendSseEvent(res, {
              type: "error",
              error: "Chatbot service error. Please try again.",
            });
            res.end();
          }
          streamEnded = true;
          req.off("close", closeHandler);
        });

      } catch (streamInitError) {
        clearTimeout(streamInitError._timeout || 0);
        console.error(`[Chatbot] Failed to initialize stream: ${streamInitError.message}`);
        if (!res.writableEnded) {
          _sendSseEvent(res, {
            type: "error",
            error: "Chatbot service unavailable. Please try again.",
          });
          res.end();
        }
        if (pythonStream && typeof pythonStream.destroy === "function") {
          pythonStream.destroy();
        }
      }

      return;
    }

    const reply = await chatBotApi(finalMessage);
    const processingTime = Date.now() - startTime;

    await _persistChatTurn(req, message, reply, processingTime, activeChatSession);

    const response = {
      success: true,
      reply,
      processing_time_ms: processingTime,
      chat_id: activeChatSession?._id || null,
    };

    // Add guest call info if available
    if (res.locals.guestCallInfo) {
      response.guest_session = {
        remaining_calls: res.locals.guestCallInfo.remaining_calls,
        call_limit: res.locals.guestCallInfo.call_limit,
        warning: res.locals.guestCallInfo.is_guest_limit_warning ? 
          "You have limited API calls remaining. Please sign up for unlimited access." : 
          null
      };
    }

    res.json(response);

  } catch (error) {
    const statusCode = error.statusCode || 500;
    console.error("Chatbot Error:", error.message);
    // console.error("Full Error:", error);

    res.status(statusCode).json({
      success: false,
      error: "Chatbot unavailable",
      details: error.message
    });
  }
};

/**
 * Get chat history for authenticated user
 */
export const getChatHistory = async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const limit = req.query.limit ? parseInt(req.query.limit) : 50;
    const skip = req.query.skip ? parseInt(req.query.skip) : 0;

    const history = await ChatHistory
      .find({ user: req.user._id, is_guest: false })
      .sort({ created_at: -1 })
      .limit(limit)
      .skip(skip)
      .select('message response original_language processing_time_ms created_at');

    const total = await ChatHistory.countDocuments({ user: req.user._id, is_guest: false });

    res.json({
      success: true,
      history,
      pagination: {
        total,
        limit,
        skip,
        remaining: Math.max(0, total - (skip + limit))
      }
    });
  } catch (error) {
    console.error("Get chat history error:", error);
    res.status(500).json({ error: "Failed to retrieve chat history" });
  }
};

/**
 * Clear chat history (optional, for user privacy)
 */
export const clearChatHistory = async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const result = await ChatHistory.deleteMany({ user: req.user._id });

    res.json({
      success: true,
      deleted_count: result.deletedCount,
      message: "Chat history cleared"
    });
  } catch (error) {
    console.error("Clear chat history error:", error);
    res.status(500).json({ error: "Failed to clear chat history" });
  }
};

/**
 * Create a new empty chat session for authenticated non-guest user
 */
export const createChatSession = async (req, res) => {
  try {
    const session = await ChatSession.create({
      user: req.user._id,
      title: "New Chat",
      is_guest: false,
      message_count: 0,
      last_message_at: new Date(),
      updated_at: new Date(),
    });

    res.status(201).json({
      success: true,
      chat: session,
    });
  } catch (error) {
    console.error("Create chat session error:", error);
    res.status(500).json({ error: "Failed to create chat session" });
  }
};

/**
 * Get all chat sessions for authenticated non-guest user
 */
export const getChatSessions = async (req, res) => {
  try {
    const limit = req.query.limit ? parseInt(req.query.limit) : 100;

    const sessions = await ChatSession.find({
      user: req.user._id,
      is_guest: false,
    })
      .sort({ updated_at: -1, last_message_at: -1, created_at: -1 })
      .limit(limit)
      .select("title message_count created_at updated_at last_message_at");

    res.json({
      success: true,
      sessions,
    });
  } catch (error) {
    console.error("Get chat sessions error:", error);
    res.status(500).json({ error: "Failed to retrieve chat sessions" });
  }
};

/**
 * Get complete ordered conversation for a specific chat session
 */
export const getChatSessionMessages = async (req, res) => {
  try {
    const { chatId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(chatId)) {
      return res.status(400).json({ error: "Invalid chatId" });
    }

    const session = await ChatSession.findOne({
      _id: chatId,
      user: req.user._id,
      is_guest: false,
    }).select("title message_count created_at updated_at last_message_at");

    if (!session) {
      return res.status(404).json({ error: "Chat session not found" });
    }

    const historyRows = await ChatHistory.find({
      user: req.user._id,
      session_id: session._id,
      is_guest: false,
    })
      .sort({ created_at: 1 })
      .select("message response created_at");

    const messages = historyRows.flatMap((row) => [
      {
        role: "user",
        text: row.message?.text || "",
        created_at: row.created_at,
      },
      {
        role: "bot",
        text: row.response?.text || "",
        created_at: row.created_at,
      },
    ]);

    res.json({
      success: true,
      chat: session,
      messages,
    });
  } catch (error) {
    console.error("Get chat session messages error:", error);
    res.status(500).json({ error: "Failed to retrieve chat messages" });
  }
};

/**
 * Delete a specific chat session and all its messages for authenticated non-guest user
 */
export const deleteChatSession = async (req, res) => {
  try {
    const { chatId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(chatId)) {
      return res.status(400).json({ error: "Invalid chatId" });
    }

    const session = await ChatSession.findOne({
      _id: chatId,
      user: req.user._id,
      is_guest: false,
    });

    if (!session) {
      return res.status(404).json({ error: "Chat session not found" });
    }

    const [messagesResult] = await Promise.all([
      ChatHistory.deleteMany({
        user: req.user._id,
        session_id: session._id,
        is_guest: false,
      }),
      ChatSession.deleteOne({ _id: session._id }),
    ]);

    res.json({
      success: true,
      deleted_chat_id: chatId,
      deleted_messages: messagesResult.deletedCount || 0,
      message: "Chat session deleted",
    });
  } catch (error) {
    console.error("Delete chat session error:", error);
    res.status(500).json({ error: "Failed to delete chat session" });
  }
};