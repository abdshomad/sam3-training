#!/usr/bin/env -S uv run python
"""
Task ID: Validate Chicken COCO Dataset
Description: Validate COCO JSON files and dataset structure
Created: 2025-12-15

This script validates:
1. COCO JSON files are valid JSON
2. All images referenced in COCO JSON exist
3. All images in directory have entries in COCO JSON
4. Bounding box coordinates are within image dimensions
5. Category IDs match expected values (1, 2)
6. Reports statistics
"""

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Dict, List, Set

from dotenv import load_dotenv

# Load environment variables
project_root = Path(__file__).parent.parent
load_dotenv(project_root / '.env')


def validate_coco_json(json_path: Path) -> tuple[Dict, List[str]]:
    """
    Validate COCO JSON file structure.
    
    Returns:
        Tuple of (coco_data, errors)
    """
    errors = []
    
    try:
        with open(json_path, 'r') as f:
            coco_data = json.load(f)
    except json.JSONDecodeError as e:
        errors.append(f"Invalid JSON: {e}")
        return None, errors
    
    # Check required top-level keys
    required_keys = ['info', 'licenses', 'categories', 'images', 'annotations']
    for key in required_keys:
        if key not in coco_data:
            errors.append(f"Missing required key: {key}")
    
    if errors:
        return None, errors
    
    # Validate categories
    categories = coco_data.get('categories', [])
    category_ids = {cat['id'] for cat in categories}
    expected_ids = {1, 2}
    
    if category_ids != expected_ids:
        errors.append(f"Category IDs mismatch. Expected {expected_ids}, got {category_ids}")
    
    # Check category names
    category_names = {cat['name'] for cat in categories}
    expected_names = {'chicken', 'not-chicken'}
    
    if category_names != expected_names:
        errors.append(f"Category names mismatch. Expected {expected_names}, got {category_names}")
    
    return coco_data, errors


def validate_images_exist(coco_data: Dict, image_dir: Path) -> List[str]:
    """
    Check that all images referenced in COCO JSON exist.
    
    Returns:
        List of errors
    """
    errors = []
    images = coco_data.get('images', [])
    
    for image in images:
        file_name = image.get('file_name')
        if not file_name:
            errors.append(f"Image entry missing file_name: {image.get('id')}")
            continue
        
        image_path = image_dir / file_name
        if not image_path.exists():
            errors.append(f"Image not found: {file_name} (image_id: {image.get('id')})")
    
    return errors


def validate_all_images_have_entries(image_dir: Path, coco_data: Dict) -> List[str]:
    """
    Check that all images in directory have entries in COCO JSON.
    
    Returns:
        List of errors
    """
    errors = []
    
    # Get all image files
    image_extensions = {'.jpg', '.jpeg', '.png', '.JPG', '.JPEG', '.PNG'}
    image_files = set()
    
    for ext in image_extensions:
        image_files.update(image_dir.glob(f'*{ext}'))
    
    # Get filenames from COCO JSON
    coco_filenames = {img['file_name'] for img in coco_data.get('images', [])}
    
    # Check for missing entries
    for image_file in image_files:
        if image_file.name not in coco_filenames:
            errors.append(f"Image file has no COCO entry: {image_file.name}")
    
    return errors


def validate_annotations(coco_data: Dict) -> List[str]:
    """
    Validate annotation bounding boxes and category IDs.
    
    Returns:
        List of errors
    """
    errors = []
    
    images_dict = {img['id']: img for img in coco_data.get('images', [])}
    annotations = coco_data.get('annotations', [])
    
    valid_category_ids = {1, 2}
    
    for ann in annotations:
        ann_id = ann.get('id')
        image_id = ann.get('image_id')
        category_id = ann.get('category_id')
        bbox = ann.get('bbox')
        
        # Check category ID
        if category_id not in valid_category_ids:
            errors.append(f"Annotation {ann_id}: Invalid category_id {category_id}")
        
        # Check image_id exists
        if image_id not in images_dict:
            errors.append(f"Annotation {ann_id}: image_id {image_id} not found in images")
            continue
        
        image_info = images_dict[image_id]
        img_width = image_info.get('width')
        img_height = image_info.get('height')
        
        # Check bbox format
        if not bbox or len(bbox) != 4:
            errors.append(f"Annotation {ann_id}: Invalid bbox format: {bbox}")
            continue
        
        x, y, width, height = bbox
        
        # Check bbox is within image bounds
        if x < 0 or y < 0:
            errors.append(f"Annotation {ann_id}: Bbox has negative coordinates: {bbox}")
        
        if x + width > img_width:
            errors.append(
                f"Annotation {ann_id}: Bbox x+width ({x+width}) exceeds image width ({img_width})"
            )
        
        if y + height > img_height:
            errors.append(
                f"Annotation {ann_id}: Bbox y+height ({y+height}) exceeds image height ({img_height})"
            )
        
        # Check area matches bbox
        expected_area = width * height
        actual_area = ann.get('area')
        if abs(expected_area - actual_area) > 0.01:  # Allow small floating point differences
            errors.append(
                f"Annotation {ann_id}: Area mismatch. Expected {expected_area}, got {actual_area}"
            )
    
    return errors


def print_statistics(coco_data: Dict, split_name: str):
    """Print dataset statistics."""
    images = coco_data.get('images', [])
    annotations = coco_data.get('annotations', [])
    categories = coco_data.get('categories', [])
    
    print(f"\n{'='*60}")
    print(f"Statistics for {split_name} split")
    print(f"{'='*60}")
    print(f"Images: {len(images)}")
    print(f"Annotations: {len(annotations)}")
    print(f"Categories: {len(categories)}")
    
    # Category distribution
    category_counts = Counter(ann['category_id'] for ann in annotations)
    category_names = {cat['id']: cat['name'] for cat in categories}
    
    print(f"\nCategory distribution:")
    for cat_id, count in sorted(category_counts.items()):
        cat_name = category_names.get(cat_id, f"unknown({cat_id})")
        print(f"  {cat_name} (id={cat_id}): {count}")
    
    # Annotations per image
    anns_per_image = Counter(ann['image_id'] for ann in annotations)
    if anns_per_image:
        print(f"\nAnnotations per image:")
        print(f"  Min: {min(anns_per_image.values())}")
        print(f"  Max: {max(anns_per_image.values())}")
        print(f"  Avg: {sum(anns_per_image.values()) / len(anns_per_image):.2f}")
        print(f"  Images with 0 annotations: {len(images) - len(anns_per_image)}")
    
    # Image dimensions
    if images:
        widths = [img['width'] for img in images]
        heights = [img['height'] for img in images]
        print(f"\nImage dimensions:")
        print(f"  Width: min={min(widths)}, max={max(widths)}, avg={sum(widths)/len(widths):.1f}")
        print(f"  Height: min={min(heights)}, max={max(heights)}, avg={sum(heights)/len(heights):.1f}")


def validate_split(split_dir: Path, split_name: str) -> bool:
    """
    Validate a single split (train/valid/test).
    
    Returns:
        True if valid, False otherwise
    """
    print(f"\n{'='*60}")
    print(f"Validating {split_name} split")
    print(f"{'='*60}")
    print(f"Directory: {split_dir}")
    
    if not split_dir.exists():
        print(f"ERROR: Directory does not exist: {split_dir}", file=sys.stderr)
        return False
    
    # Find COCO JSON file
    coco_json = split_dir / '_annotations.coco.json'
    
    if not coco_json.exists():
        print(f"ERROR: COCO JSON file not found: {coco_json}", file=sys.stderr)
        return False
    
    print(f"COCO JSON: {coco_json}")
    
    # Validate JSON structure
    coco_data, errors = validate_coco_json(coco_json)
    
    if errors:
        print(f"\nERRORS in JSON structure:")
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return False
    
    print("✓ JSON structure is valid")
    
    # Validate images exist
    image_errors = validate_images_exist(coco_data, split_dir)
    if image_errors:
        print(f"\nERRORS: Missing images ({len(image_errors)}):")
        for error in image_errors[:10]:  # Show first 10
            print(f"  - {error}", file=sys.stderr)
        if len(image_errors) > 10:
            print(f"  ... and {len(image_errors) - 10} more", file=sys.stderr)
        return False
    
    print("✓ All referenced images exist")
    
    # Validate all images have entries
    missing_entry_errors = validate_all_images_have_entries(split_dir, coco_data)
    if missing_entry_errors:
        print(f"\nWARNINGS: Images without COCO entries ({len(missing_entry_errors)}):")
        for error in missing_entry_errors[:10]:  # Show first 10
            print(f"  - {error}", file=sys.stderr)
        if len(missing_entry_errors) > 10:
            print(f"  ... and {len(missing_entry_errors) - 10} more", file=sys.stderr)
        # This is a warning, not a fatal error
    
    # Validate annotations
    ann_errors = validate_annotations(coco_data)
    if ann_errors:
        print(f"\nERRORS in annotations ({len(ann_errors)}):")
        for error in ann_errors[:20]:  # Show first 20
            print(f"  - {error}", file=sys.stderr)
        if len(ann_errors) > 20:
            print(f"  ... and {len(ann_errors) - 20} more", file=sys.stderr)
        return False
    
    print("✓ All annotations are valid")
    
    # Print statistics
    print_statistics(coco_data, split_name)
    
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Validate chicken dataset COCO format"
    )
    parser.add_argument(
        '--dataset-root',
        type=Path,
        default=Path('data/chicken-and-not-chicken'),
        help='Root directory of COCO format dataset (default: data/chicken-and-not-chicken)'
    )
    parser.add_argument(
        '--split',
        choices=['train', 'valid', 'test', 'all'],
        default='all',
        help='Which split to validate (default: all)'
    )
    
    args = parser.parse_args()
    
    dataset_root = args.dataset_root.resolve()
    
    if not dataset_root.exists():
        print(f"Error: Dataset root does not exist: {dataset_root}", file=sys.stderr)
        sys.exit(1)
    
    print("=" * 60)
    print("Chicken Dataset COCO Validation")
    print("=" * 60)
    print(f"Dataset root: {dataset_root}")
    print(f"Split: {args.split}")
    
    splits_to_validate = []
    
    if args.split == 'all':
        splits_to_validate = ['train', 'valid', 'test']
    else:
        splits_to_validate = [args.split]
    
    all_valid = True
    
    for split_name in splits_to_validate:
        split_dir = dataset_root / split_name
        if not validate_split(split_dir, split_name):
            all_valid = False
    
    print("\n" + "=" * 60)
    if all_valid:
        print("✓ All validations passed!")
        return 0
    else:
        print("✗ Validation failed. Please check errors above.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
