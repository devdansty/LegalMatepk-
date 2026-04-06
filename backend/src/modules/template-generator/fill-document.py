#!/usr/bin/env python3
"""
fill-document.py
Fills placeholders in a .docx template with provided values.

Usage:
  python fill-document.py <input_file> <output_file> <json_values>
  
Example:
  python fill-document.py template.docx filled.docx '{"name":"Ali","email":"ali@example.com"}'
"""

import sys
import json
from docx import Document
from docx.oxml import parse_xml
from pathlib import Path


def replace_placeholders_in_document(doc, replacements):
    """
    Replace all {{placeholder}} occurrences in document with provided values.
    Works across paragraphs, tables, and other elements.
    """
    
    # Replace in paragraphs
    for paragraph in doc.paragraphs:
        for run in paragraph.runs:
            for placeholder, value in replacements.items():
                if f"{{{{{placeholder}}}}}" in run.text:
                    run.text = run.text.replace(
                        f"{{{{{placeholder}}}}}",
                        str(value)
                    )
    
    # Replace in tables
    for table in doc.tables:
        for row in table.rows:
            for cell in row.cells:
                for paragraph in cell.paragraphs:
                    for run in paragraph.runs:
                        for placeholder, value in replacements.items():
                            if f"{{{{{placeholder}}}}}" in run.text:
                                run.text = run.text.replace(
                                    f"{{{{{placeholder}}}}}",
                                    str(value)
                                )
    
    # Replace in headers
    for section in doc.sections:
        for paragraph in section.header.paragraphs:
            for run in paragraph.runs:
                for placeholder, value in replacements.items():
                    if f"{{{{{placeholder}}}}}" in run.text:
                        run.text = run.text.replace(
                            f"{{{{{placeholder}}}}}",
                            str(value)
                        )
    
    # Replace in footers
    for section in doc.sections:
        for paragraph in section.footer.paragraphs:
            for run in paragraph.runs:
                for placeholder, value in replacements.items():
                    if f"{{{{{placeholder}}}}}" in run.text:
                        run.text = run.text.replace(
                            f"{{{{{placeholder}}}}}",
                            str(value)
                        )


def fill_document(input_file, output_file, replacements):
    """
    Main function to fill .docx document with values.
    
    Args:
        input_file: Path to original template .docx
        output_file: Path to save filled document
        replacements: Dict of {placeholder: value}
    
    Returns:
        True if successful, False otherwise
    """
    try:
        # Validate input file exists
        if not Path(input_file).exists():
            print(f"ERROR: Input file not found: {input_file}", file=sys.stderr)
            return False
        
        # Load document
        doc = Document(input_file)
        
        # Replace placeholders
        replace_placeholders_in_document(doc, replacements)
        
        # Ensure output directory exists
        output_path = Path(output_file)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Save filled document
        doc.save(output_file)
        
        return True
    
    except Exception as e:
        print(f"ERROR: {str(e)}", file=sys.stderr)
        return False


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: python fill-document.py <input_file> <output_file> <json_values>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    json_values = sys.argv[3]
    
    try:
        replacements = json.loads(json_values)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON: {str(e)}", file=sys.stderr)
        sys.exit(1)
    
    success = fill_document(input_file, output_file, replacements)
    
    if success:
        print(f"SUCCESS: {output_file}")
        sys.exit(0)
    else:
        sys.exit(1)
