#!/usr/bin/env -S uv run python
"""
Task ID: Convert Labelme to COCO
Description: Convert Labelme JSON annotations to COCO format
Created: 2025-12-15

This script converts Labelme JSON annotation files to COCO format JSON.
It handles bounding box conversion from Labelme format [[x1,y1], [x2,y2]] 
to COCO format [x, y, width, height].
"""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple

from dotenv import load_dotenv

# Load environment variables
project_root = Path(__file__).parent.parent
load_dotenv(project_root / '.env')


def convert_labelme_bbox_to_coco(points: List[List[float]]) -> Tuple[float, float, float, float]:
    """
    Convert Labelme bounding box format to COCO format.
    
    Args:
        points: [[x1, y1], [x2, y2]] - top-left and bottom-right corners
        
    Returns:
        Tuple of (x, y, width, height) in COCO format
    """
    if len(points) != 2:
        raise ValueError(f"Expected 2 points for rectangle, got {len(points)}")
    
    x1, y1 = points[0]
    x2, y2 = points[1]
    
    # COCO format: [x, y, width, height] where (x,y) is top-left corner
    x = min(x1, x2)
    y = min(y1, y2)
    width = abs(x2 - x1)
    height = abs(y2 - y1)
    
    return (x, y, width, height)


def get_category_id(label: str) -> int:
    """
    Map label name to category ID.
    
    Args:
        label: Label name ("chicken" or "not-chicken")
        
    Returns:
        Category ID (1 for chicken, 2 for not-chicken)
    """
    label_map = {
        "chicken": 1,
        "not-chicken": 2,
    }
    
    label_lower = label.lower().strip()
    if label_lower not in label_map:
        raise ValueError(f"Unknown label: {label}. Expected 'chicken' or 'not-chicken'")
    
    return label_map[label_lower]


def convert_labelme_to_coco(
    labelme_json_path: Path,
    image_filename: str,
    image_id: int,
    annotation_id_start: int = 0
) -> Tuple[Dict, List[Dict], int]:
    """
    Convert a single Labelme JSON file to COCO format entries.
    
    Args:
        labelme_json_path: Path to Labelme JSON file
        image_filename: Filename of the image (for COCO image entry)
        image_id: Unique ID for the image
        annotation_id_start: Starting ID for annotations
        
    Returns:
        Tuple of (image_dict, annotations_list, next_annotation_id)
    """
    # Load Labelme JSON
    with open(labelme_json_path, 'r') as f:
        labelme_data = json.load(f)
    
    # Get image dimensions
    height = labelme_data.get('imageHeight')
    width = labelme_data.get('imageWidth')
    
    if height is None or width is None:
        raise ValueError(f"Missing imageHeight or imageWidth in {labelme_json_path}")
    
    # Create COCO image entry
    image_entry = {
        "id": image_id,
        "license": 1,
        "file_name": image_filename,
        "height": height,
        "width": width,
        "date_captured": datetime.now().strftime("%Y-%m-%dT%H:%M:%S+00:00")
    }
    
    # Convert annotations
    annotations = []
    annotation_id = annotation_id_start
    
    for shape in labelme_data.get('shapes', []):
        if shape.get('shape_type') != 'rectangle':
            # Skip non-rectangle shapes
            continue
        
        label = shape.get('label')
        points = shape.get('points')
        
        if not label or not points:
            continue
        
        try:
            # Convert bounding box
            x, y, bbox_width, bbox_height = convert_labelme_bbox_to_coco(points)
            
            # Get category ID
            category_id = get_category_id(label)
            
            # Calculate area
            area = bbox_width * bbox_height
            
            # Create annotation entry
            annotation = {
                "id": annotation_id,
                "image_id": image_id,
                "category_id": category_id,
                "bbox": [x, y, bbox_width, bbox_height],
                "area": area,
                "segmentation": [],  # Empty for bounding box-only annotations
                "iscrowd": 0
            }
            
            annotations.append(annotation)
            annotation_id += 1
            
        except (ValueError, KeyError) as e:
            print(f"Warning: Skipping annotation in {labelme_json_path}: {e}", file=sys.stderr)
            continue
    
    return image_entry, annotations, annotation_id


def create_coco_json(
    images: List[Dict],
    annotations: List[Dict],
    output_path: Path
) -> None:
    """
    Create a COCO format JSON file.
    
    Args:
        images: List of image dictionaries
        annotations: List of annotation dictionaries
        output_path: Path to output JSON file
    """
    # Define categories
    categories = [
        {
            "id": 1,
            "name": "chicken",
            "supercategory": "none"
        },
        {
            "id": 2,
            "name": "not-chicken",
            "supercategory": "none"
        }
    ]
    
    # Create COCO structure
    coco_data = {
        "info": {
            "year": "2025",
            "version": "1.0",
            "description": "Chicken Detection Dataset - Converted from Labelme format",
            "contributor": "SAM3 Training",
            "url": "",
            "date_created": datetime.now().strftime("%Y-%m-%dT%H:%M:%S+00:00")
        },
        "licenses": [
            {
                "id": 1,
                "url": "https://choosealicense.com/licenses/mit/",
                "name": "MIT"
            }
        ],
        "categories": categories,
        "images": images,
        "annotations": annotations
    }
    
    # Write to file
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'w') as f:
        json.dump(coco_data, f, indent=4)
    
    print(f"Created COCO JSON: {output_path}")
    print(f"  Images: {len(images)}")
    print(f"  Annotations: {len(annotations)}")


def main():
    parser = argparse.ArgumentParser(
        description="Convert Labelme JSON annotations to COCO format"
    )
    parser.add_argument(
        '--input-dir',
        type=Path,
        required=True,
        help='Input directory containing Labelme JSON files'
    )
    parser.add_argument(
        '--output',
        type=Path,
        required=True,
        help='Output path for COCO JSON file'
    )
    parser.add_argument(
        '--image-dir',
        type=Path,
        help='Directory containing images (for filename extraction). If not provided, uses input-dir'
    )
    
    args = parser.parse_args()
    
    input_dir = args.input_dir
    output_path = args.output
    image_dir = args.image_dir or input_dir
    
    if not input_dir.exists():
        print(f"Error: Input directory does not exist: {input_dir}", file=sys.stderr)
        sys.exit(1)
    
    # Find all JSON files
    json_files = sorted(input_dir.glob('*.json'))
    
    if not json_files:
        print(f"Error: No JSON files found in {input_dir}", file=sys.stderr)
        sys.exit(1)
    
    print(f"Found {len(json_files)} JSON files in {input_dir}")
    
    # Process files
    images = []
    annotations = []
    image_id = 0
    annotation_id = 0
    
    for json_file in json_files:
        # Get corresponding image filename
        # Labelme JSON files typically have same name as image but with .json extension
        image_filename = json_file.stem + '.jpg'  # Assume JPG format
        
        # Check if image exists
        image_path = image_dir / image_filename
        if not image_path.exists():
            # Try other extensions
            for ext in ['.png', '.jpeg', '.JPG', '.PNG', '.JPEG']:
                alt_path = image_dir / (json_file.stem + ext)
                if alt_path.exists():
                    image_filename = json_file.stem + ext
                    break
            else:
                print(f"Warning: Image not found for {json_file.name}, skipping", file=sys.stderr)
                continue
        
        try:
            image_entry, image_annotations, next_annotation_id = convert_labelme_to_coco(
                json_file,
                image_filename,
                image_id,
                annotation_id
            )
            
            images.append(image_entry)
            annotations.extend(image_annotations)
            
            image_id += 1
            annotation_id = next_annotation_id
            
        except Exception as e:
            print(f"Error processing {json_file.name}: {e}", file=sys.stderr)
            continue
    
    # Create COCO JSON
    if images:
        create_coco_json(images, annotations, output_path)
        print(f"\nConversion complete!")
        print(f"  Total images: {len(images)}")
        print(f"  Total annotations: {len(annotations)}")
    else:
        print("Error: No valid images processed", file=sys.stderr)
        sys.exit(1)
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
