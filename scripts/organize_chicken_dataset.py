#!/usr/bin/env -S uv run python
"""
Task ID: Organize Chicken Dataset
Description: Organize chicken dataset from Labelme format to COCO format structure
Created: 2025-12-15

This script:
1. Creates directory structure: data/chicken-and-not-chicken/{train,valid,test}/
2. Splits validation data: 80% valid, 20% test
3. Copies images from source to target directories
4. Generates COCO annotation files for each split
"""

import argparse
import random
import shutil
import subprocess
import sys
from pathlib import Path
from typing import List

from dotenv import load_dotenv

# Load environment variables
project_root = Path(__file__).parent.parent
load_dotenv(project_root / '.env')


def setup_random_seed(seed: int = 42):
    """Set random seed for reproducible splits."""
    random.seed(seed)


def get_image_files(directory: Path) -> List[Path]:
    """Get all image files from a directory."""
    image_extensions = {'.jpg', '.jpeg', '.png', '.JPG', '.JPEG', '.PNG'}
    image_files = []
    
    for ext in image_extensions:
        image_files.extend(directory.glob(f'*{ext}'))
    
    return sorted(image_files)


def get_json_files(directory: Path) -> List[Path]:
    """Get all JSON files from a directory."""
    return sorted(directory.glob('*.json'))


def copy_file(src: Path, dst: Path) -> bool:
    """Copy a file from source to destination."""
    try:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        return True
    except Exception as e:
        print(f"Error copying {src} to {dst}: {e}", file=sys.stderr)
        return False


def split_validation_data(val_files: List[Path], valid_ratio: float = 0.8) -> tuple:
    """
    Split validation files into valid and test sets.
    
    Args:
        val_files: List of validation files
        valid_ratio: Ratio for valid set (default 0.8 = 80%)
        
    Returns:
        Tuple of (valid_files, test_files)
    """
    # Shuffle for random split
    shuffled = val_files.copy()
    random.shuffle(shuffled)
    
    # Calculate split point
    split_idx = int(len(shuffled) * valid_ratio)
    
    valid_files = shuffled[:split_idx]
    test_files = shuffled[split_idx:]
    
    return valid_files, test_files


def process_split(
    source_dir: Path,
    target_dir: Path,
    split_name: str,
    conversion_script: Path
) -> bool:
    """
    Process a single split: copy images and generate COCO JSON.
    
    Args:
        source_dir: Source directory with Labelme JSON files
        target_dir: Target directory for COCO format
        split_name: Name of the split (for logging)
        conversion_script: Path to convert_labelme_to_coco.py script
        
    Returns:
        True if successful, False otherwise
    """
    print(f"\nProcessing {split_name} split...")
    print(f"  Source: {source_dir}")
    print(f"  Target: {target_dir}")
    
    # Get JSON files
    json_files = get_json_files(source_dir)
    
    if not json_files:
        print(f"  Warning: No JSON files found in {source_dir}", file=sys.stderr)
        return False
    
    print(f"  Found {len(json_files)} JSON files")
    
    # Copy images and collect image filenames
    image_files = get_image_files(source_dir)
    copied_count = 0
    
    for image_file in image_files:
        target_image = target_dir / image_file.name
        if copy_file(image_file, target_image):
            copied_count += 1
    
    print(f"  Copied {copied_count} images")
    
    # Generate COCO JSON using conversion script
    coco_json_path = target_dir / '_annotations.coco.json'
    
    print(f"  Generating COCO JSON: {coco_json_path}")
    
    try:
        result = subprocess.run(
            [
                sys.executable,
                str(conversion_script),
                '--input-dir', str(source_dir),
                '--output', str(coco_json_path),
                '--image-dir', str(source_dir)
            ],
            check=True,
            capture_output=True,
            text=True
        )
        
        print(f"  ✓ COCO JSON generated successfully")
        if result.stdout:
            print(f"  {result.stdout}")
        
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"  Error generating COCO JSON: {e}", file=sys.stderr)
        if e.stderr:
            print(f"  {e.stderr}", file=sys.stderr)
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Organize chicken dataset from Labelme to COCO format"
    )
    parser.add_argument(
        '--source-root',
        type=Path,
        default=Path('chicken-detection-labelme-format'),
        help='Root directory of source Labelme dataset (default: chicken-detection-labelme-format)'
    )
    parser.add_argument(
        '--target-root',
        type=Path,
        default=Path('data/chicken-and-not-chicken'),
        help='Root directory for COCO format dataset (default: data/chicken-and-not-chicken)'
    )
    parser.add_argument(
        '--valid-ratio',
        type=float,
        default=0.8,
        help='Ratio for valid split (default: 0.8, meaning 80%% valid, 20%% test)'
    )
    parser.add_argument(
        '--seed',
        type=int,
        default=42,
        help='Random seed for splitting validation data (default: 42)'
    )
    parser.add_argument(
        '--skip-train',
        action='store_true',
        help='Skip processing train split'
    )
    parser.add_argument(
        '--skip-val',
        action='store_true',
        help='Skip processing validation split'
    )
    
    args = parser.parse_args()
    
    source_root = args.source_root.resolve()
    target_root = args.target_root.resolve()
    
    if not source_root.exists():
        print(f"Error: Source directory does not exist: {source_root}", file=sys.stderr)
        sys.exit(1)
    
    # Set random seed
    setup_random_seed(args.seed)
    
    # Get conversion script path
    script_dir = Path(__file__).parent
    conversion_script = script_dir / 'convert_labelme_to_coco.py'
    
    if not conversion_script.exists():
        print(f"Error: Conversion script not found: {conversion_script}", file=sys.stderr)
        sys.exit(1)
    
    print("=" * 60)
    print("Chicken Dataset Organization")
    print("=" * 60)
    print(f"Source root: {source_root}")
    print(f"Target root: {target_root}")
    print(f"Valid ratio: {args.valid_ratio}")
    print(f"Random seed: {args.seed}")
    print()
    
    success = True
    
    # Process train split
    if not args.skip_train:
        train_source = source_root / 'train'
        train_target = target_root / 'train'
        
        if train_source.exists():
            if not process_split(train_source, train_target, 'train', conversion_script):
                success = False
        else:
            print(f"Warning: Train directory not found: {train_source}", file=sys.stderr)
            success = False
    
    # Process validation split (split into valid and test)
    if not args.skip_val:
        val_source = source_root / 'val'
        
        if val_source.exists():
            # Get all JSON files from val directory
            val_json_files = get_json_files(val_source)
            
            if val_json_files:
                # Split into valid and test
                valid_json_files, test_json_files = split_validation_data(
                    val_json_files,
                    args.valid_ratio
                )
                
                print(f"\nValidation split:")
                print(f"  Total files: {len(val_json_files)}")
                print(f"  Valid: {len(valid_json_files)} ({len(valid_json_files)/len(val_json_files)*100:.1f}%)")
                print(f"  Test: {len(test_json_files)} ({len(test_json_files)/len(val_json_files)*100:.1f}%)")
                
                # Create temporary directories for split processing
                import tempfile
                with tempfile.TemporaryDirectory() as temp_dir:
                    temp_path = Path(temp_dir)
                    
                    # Create valid and test subdirectories
                    valid_temp = temp_path / 'valid'
                    test_temp = temp_path / 'test'
                    valid_temp.mkdir()
                    test_temp.mkdir()
                    
                    # Copy JSON files to temp directories
                    for json_file in valid_json_files:
                        shutil.copy2(json_file, valid_temp / json_file.name)
                        # Also copy corresponding image if it exists
                        image_file = val_source / (json_file.stem + '.jpg')
                        if not image_file.exists():
                            for ext in ['.png', '.jpeg', '.JPG', '.PNG', '.JPEG']:
                                alt_image = val_source / (json_file.stem + ext)
                                if alt_image.exists():
                                    image_file = alt_image
                                    break
                        if image_file.exists():
                            shutil.copy2(image_file, valid_temp / image_file.name)
                    
                    for json_file in test_json_files:
                        shutil.copy2(json_file, test_temp / json_file.name)
                        # Also copy corresponding image if it exists
                        image_file = val_source / (json_file.stem + '.jpg')
                        if not image_file.exists():
                            for ext in ['.png', '.jpeg', '.JPG', '.PNG', '.JPEG']:
                                alt_image = val_source / (json_file.stem + ext)
                                if alt_image.exists():
                                    image_file = alt_image
                                    break
                        if image_file.exists():
                            shutil.copy2(image_file, test_temp / image_file.name)
                    
                    # Process valid split
                    valid_target = target_root / 'valid'
                    if not process_split(valid_temp, valid_target, 'valid', conversion_script):
                        success = False
                    
                    # Process test split
                    test_target = target_root / 'test'
                    if not process_split(test_temp, test_target, 'test', conversion_script):
                        success = False
            else:
                print(f"Warning: No JSON files found in {val_source}", file=sys.stderr)
                success = False
        else:
            print(f"Warning: Validation directory not found: {val_source}", file=sys.stderr)
            success = False
    
    # Summary
    print("\n" + "=" * 60)
    if success:
        print("✓ Dataset organization completed successfully!")
        print(f"\nDataset structure created at: {target_root}")
        print("  - train/")
        print("  - valid/")
        print("  - test/")
    else:
        print("⚠ Dataset organization completed with warnings/errors")
        print("  Please check the output above for details")
        sys.exit(1)
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
