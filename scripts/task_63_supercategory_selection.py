#!/usr/bin/env -S uv run python
"""
Task ID: 6.3
Description: Supercategory Selection Helper
Created: 2025-12-13

This utility helps select which supercategory to train on by listing available
supercategories in the rf100-vl dataset and allowing selection of single or all
supercategories (for job arrays).
"""

import argparse
import json
import sys
from pathlib import Path
from typing import List, Optional

from dotenv import load_dotenv
import yaml

# Load environment variables from .env and .env.rf100vl files
project_root = Path(__file__).parent.parent
load_dotenv(project_root / '.env')
load_dotenv(project_root / '.env.rf100vl')  # RF100-VL specific settings


def get_project_root() -> Path:
    """Get the project root directory."""
    script_dir = Path(__file__).parent
    return script_dir.parent


def load_supercategories_from_config(config_path: Path) -> List[str]:
    """Load supercategories from the config file."""
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f)
    
    return config.get('all_roboflow_supercategories', [])


def load_supercategories_from_dataset(roboflow_root: Path) -> List[str]:
    """Load supercategories by scanning the dataset directory."""
    if not roboflow_root.exists():
        return []
    
    # Get all subdirectories that look like datasets
    supercategories = []
    for item in roboflow_root.iterdir():
        if item.is_dir():
            # Check if it has train/test/valid subdirectories
            has_train = (item / 'train').exists()
            has_test = (item / 'test').exists()
            has_valid = (item / 'valid').exists()
            
            if has_train or has_test or has_valid:
                supercategories.append(item.name)
    
    return sorted(supercategories)


def get_supercategory_category_mapping() -> dict:
    """Get mapping of supercategory names to their categories."""
    # Try to load from rf100-vl package
    try:
        rf100vl_assets = get_project_root() / 'rf100-vl' / 'rf100vl' / 'assets' / 'dataset_name_to_category.json'
        if rf100vl_assets.exists():
            with open(rf100vl_assets, 'r') as f:
                return json.load(f)
    except Exception:
        pass
    
    return {}


def list_supercategories(
    supercategories: List[str],
    category_map: Optional[dict] = None,
    show_categories: bool = True
) -> None:
    """List all available supercategories."""
    print(f"\nAvailable Supercategories ({len(supercategories)} total):")
    print("=" * 80)
    
    if category_map and show_categories:
        # Group by category
        categories = {}
        for sc in supercategories:
            cat = category_map.get(sc, "Unknown")
            if cat not in categories:
                categories[cat] = []
            categories[cat].append(sc)
        
        for cat in sorted(categories.keys()):
            print(f"\n{cat}:")
            for sc in sorted(categories[cat]):
                print(f"  - {sc}")
    else:
        # Just list them
        for i, sc in enumerate(supercategories, 1):
            print(f"{i:3d}. {sc}")


def interactive_selection(supercategories: List[str]) -> Optional[str]:
    """Interactively select a supercategory."""
    if not supercategories:
        print("No supercategories available", file=sys.stderr)
        return None
    
    list_supercategories(supercategories, show_categories=False)
    
    print("\nOptions:")
    print("  Enter a number (1-{}) to select a supercategory".format(len(supercategories)))
    print("  Enter 'all' to select all supercategories (for job array)")
    print("  Enter 'q' to quit")
    
    while True:
        try:
            choice = input("\nYour choice: ").strip().lower()
            
            if choice == 'q':
                return None
            elif choice == 'all':
                return 'all'
            elif choice.isdigit():
                idx = int(choice) - 1
                if 0 <= idx < len(supercategories):
                    return supercategories[idx]
                else:
                    print(f"Invalid number. Please enter 1-{len(supercategories)}")
            else:
                print("Invalid choice. Please enter a number, 'all', or 'q'")
        except (EOFError, KeyboardInterrupt):
            print("\nCancelled")
            return None


def generate_config_override(supercategory: str, config_path: Path) -> str:
    """Generate a config override string for the selected supercategory."""
    if supercategory == 'all':
        # For job array, use the existing job array syntax
        return "${all_roboflow_supercategories.${string:${submitit.job_array.task_index}}}"
    else:
        # For single supercategory, just return it
        return supercategory


def main() -> int:
    """Main function."""
    parser = argparse.ArgumentParser(
        description='List and select supercategories for RF100-VL training'
    )
    parser.add_argument(
        '--config',
        type=str,
        default='sam3/sam3/train/configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml',
        help='Path to config file (relative to project root)'
    )
    parser.add_argument(
        '--roboflow-root',
        type=str,
        help='Path to Roboflow dataset root (to scan for available datasets)'
    )
    parser.add_argument(
        '--list',
        action='store_true',
        help='Just list supercategories and exit'
    )
    parser.add_argument(
        '--select',
        type=str,
        help='Select a specific supercategory by name (non-interactive)'
    )
    parser.add_argument(
        '--all',
        action='store_true',
        help='Select all supercategories (for job array)'
    )
    parser.add_argument(
        '--show-categories',
        action='store_true',
        help='Group supercategories by category when listing'
    )
    parser.add_argument(
        '--output-override',
        action='store_true',
        help='Output config override string for selected supercategory'
    )
    
    args = parser.parse_args()
    
    project_root = get_project_root()
    
    # Load supercategories
    config_path = project_root / args.config
    supercategories = load_supercategories_from_config(config_path)
    
    # Also try to load from dataset directory if provided
    if args.roboflow_root:
        dataset_root = project_root / args.roboflow_root if not Path(args.roboflow_root).is_absolute() else Path(args.roboflow_root)
        dataset_supercategories = load_supercategories_from_dataset(dataset_root)
        if dataset_supercategories:
            # Merge and deduplicate
            all_supercategories = list(set(supercategories + dataset_supercategories))
            supercategories = sorted(all_supercategories)
            print(f"Found {len(dataset_supercategories)} supercategories in dataset directory")
    
    if not supercategories:
        print("ERROR: No supercategories found", file=sys.stderr)
        return 1
    
    # Load category mapping
    category_map = get_supercategory_category_mapping() if args.show_categories else None
    
    # List supercategories
    if args.list or args.select or args.all:
        list_supercategories(supercategories, category_map, args.show_categories)
    
    # Handle selection
    selected = None
    
    if args.all:
        selected = 'all'
    elif args.select:
        if args.select in supercategories:
            selected = args.select
        else:
            print(f"ERROR: Supercategory '{args.select}' not found", file=sys.stderr)
            print(f"Available supercategories: {', '.join(supercategories[:10])}...")
            return 1
    elif args.list:
        # Just list, no selection needed
        return 0
    else:
        # If no arguments provided, default to "all" (non-interactive)
        # This allows the script to run in automated contexts like run-all-scripts.sh
        selected = 'all'  # Default to all supercategories
    
    # Output result
    if selected:
        if args.output_override:
            override = generate_config_override(selected, config_path)
            print(f"\nConfig override for roboflow_train.supercategory:")
            print(f"  {override}")
        else:
            if selected == 'all':
                print(f"\nSelected: All supercategories (for job array)")
                print(f"Total: {len(supercategories)} supercategories")
            else:
                print(f"\nSelected: {selected}")
                if category_map:
                    cat = category_map.get(selected, "Unknown")
                    print(f"Category: {cat}")
        return 0
    elif args.list:
        return 0
    else:
        return 1


if __name__ == '__main__':
    sys.exit(main())

