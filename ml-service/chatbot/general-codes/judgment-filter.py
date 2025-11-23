import os
import shutil
from pathlib import Path
from transformers import pipeline

# Initialize zero-shot classification model
print("Loading AI model... (this may take a minute on first run)")
classifier = pipeline("zero-shot-classification", model="facebook/bart-large-mnli",device=-1)  # Use CPU

def is_property_related(text, threshold=0.3):
    """
    Determine if judgment text is property-related using AI classification
    
    Args:
        text: Judgment text content
        threshold: Confidence threshold (0.3 = lenient, 0.5 = moderate, 0.7 = strict)
    
    Returns:
        Boolean indicating if text is property-related
    """
    
    # Take first 2000 characters for faster processing
    # (Usually introduction and case summary are at the beginning)
    sample_text = text[:2000]
    
    # Property-related categories (comprehensive)
    property_labels = [
        "property dispute, land ownership, title dispute, possession of land",
        "inheritance of property, succession rights, property distribution among heirs",
        "sale and purchase of property, transfer of property, sale deed disputes",
        "mutation of land records, revenue records, patwari records",
        "boundary disputes, encroachment, trespassing on land",
        "pre-emption rights, shufaa, right of pre-emption in property sale",
        "agricultural land disputes, farming land ownership",
        "residential or commercial property disputes",
        "rent and lease agreements, tenant and landlord disputes",
        "benami transactions, property held in another's name",
        "immovable property, real estate disputes",
        "land acquisition, eminent domain, government land taking",
        "easement rights, right of way, access to property",
        "adverse possession, occupancy rights, possessory title",
        "partition of property, division of joint property",
        "mortgage and lien on property, property as collateral"
    ]
    
    # Non-property categories for comparison
    non_property_labels = [
        "service matters, employment disputes, job termination",
        "criminal matters, criminal prosecution, criminal appeals",
        "constitutional matters, fundamental rights, constitutional petitions",
        "taxation, tax disputes, revenue collection",
        "contract disputes not involving property, commercial contracts",
        "family matters like divorce, custody, maintenance",
        "election disputes, electoral matters"
    ]
    
    # Combine all labels
    all_labels = property_labels + non_property_labels
    
    try:
        # Classify the text
        result = classifier(sample_text, all_labels, multi_label=True)
        
        # Check if any property-related label has high confidence
        for label, score in zip(result['labels'], result['scores']):
            if label in property_labels and score > threshold:
                return True
        
        return False
    
    except Exception as e:
        print(f"  Warning: Classification error - {e}")
        # Fallback to keyword matching if AI fails
        return keyword_fallback(text)


def keyword_fallback(text):
    """
    Fallback keyword-based detection if AI classification fails
    """
    text_lower = text.lower()
    
    # Comprehensive property-related keywords
    property_keywords = [
        # Core property terms
        'property', 'land', 'immovable', 'plot', 'estate',
        
        # Ownership and title
        'ownership', 'title', 'deed', 'sale deed', 'gift deed',
        'transfer deed', 'conveyance', 'registry',
        
        # Possession
        'possession', 'occupancy', 'adverse possession', 
        'khasra', 'khewat', 'khatauni',
        
        # Land records
        'mutation', 'patwari', 'revenue', 'jamabandi', 
        'fard', 'intiqal', 'tehsildar',
        
        # Types of property
        'agricultural land', 'residential property', 'commercial property',
        'house', 'building', 'apartment', 'flat',
        
        # Disputes
        'encroachment', 'trespass', 'boundary dispute', 'partition',
        'easement', 'right of way', 'inheritance', 'succession',
        
        # Legal terms
        'pre-emption', 'shufaa', 'benami', 'specific performance',
        'injunction', 'suit for possession', 'suit for declaration',
        
        # Laws (Pakistani property laws)
        'transfer of property act', 'land revenue act',
        'land acquisition act', 'colonization act',
        'succession act', 'pre-emption act'
    ]
    
    # Count keyword matches
    matches = sum(1 for keyword in property_keywords if keyword in text_lower)
    
    # If more than 3 property keywords found, consider it property-related
    return matches >= 3


def filter_property_judgments(source_folder, output_folder):
    """
    Filter and copy property-related judgment files
    
    Args:
        source_folder: Path to folder containing all judgment files
        output_folder: Path where property-related files will be copied
    """
    
    # Create output folder if it doesn't exist
    output_path = Path(output_folder)
    output_path.mkdir(exist_ok=True)
    
    # Get all .txt files
    source_path = Path(source_folder)
    txt_files = list(source_path.glob('*.txt'))
    
    total_files = len(txt_files)
    property_count = 0
    
    print(f"\nFound {total_files} judgment files to process...")
    print("Processing files...\n")
    
    for i, file_path in enumerate(txt_files, 1):
        # Progress indicator
        if i % 10 == 0 or i == 1:
            print(f"Processing file {i}/{total_files}...")
        
        try:
            # Read file content
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            # Check if property-related
            if is_property_related(content):
                # Copy file to output folder
                destination = output_path / file_path.name
                shutil.copy2(file_path, destination)
                property_count += 1
        
        except Exception as e:
            print(f"  Error processing {file_path.name}: {e}")
            continue
    
    # Final message
    print("\n" + "="*60)
    print("✓ DONE!")
    print(f"✓ Total files processed: {total_files}")
    print(f"✓ Property-related files found: {property_count}")
    print(f"✓ Files copied to: {output_path.absolute()}")
    print("="*60)


if __name__ == "__main__":
    # ========== CONFIGURE THESE PATHS ==========
    
    SOURCE_FOLDER = r"E:\CODE\FYP\application\docs\Supreme_court_Of_Pakistan_judgments"  # Change this to your folder path
    OUTPUT_FOLDER = r"E:\CODE\FYP\application\docs\property_related_judgments"  # Output folder name
    
    # ===========================================
    
    print("\n" + "="*60)
    print("Property Judgment Filter Script")
    print("="*60)
    
    # Validate source folder
    if not os.path.exists(SOURCE_FOLDER):
        print(f"\n❌ Error: Source folder not found: {SOURCE_FOLDER}")
        print("Please update SOURCE_FOLDER path in the script.")
        exit(1)
    
    # Run the filter
    filter_property_judgments(SOURCE_FOLDER, OUTPUT_FOLDER)