#!/usr/bin/env -S uv run python
"""
Task ID: Chicken Config Path Resolution
Description: Resolve and update config file paths for Chicken Detection training
Created: 2025-12-15

This script resolves and updates config file paths (chicken_data_root, 
experiment_log_dir, bpe_path) from environment variables or CLI args, 
replacing placeholders in the base config.
"""

import argparse
import os
import sys
from pathlib import Path
from typing import Optional

from dotenv import load_dotenv
import yaml

# Load environment variables from .env and .env.chicken files
project_root = Path(__file__).parent.parent
load_dotenv(project_root / '.env')
load_dotenv(project_root / '.env.chicken')  # Chicken specific settings


def get_project_root() -> Path:
    """Get the project root directory."""
    script_dir = Path(__file__).parent
    return script_dir.parent


def load_base_config(config_path: Path) -> dict:
    """Load the base config YAML file."""
    if not config_path.exists():
        raise FileNotFoundError(f"Config file not found: {config_path}")
    
    with open(config_path, 'r') as f:
        return yaml.safe_load(f)


def resolve_path(path_str: str, project_root: Path) -> Path:
    """Resolve a path string to an absolute Path."""
    if not path_str:
        return None
    
    # Convert to Path
    path = Path(path_str)
    
    # If relative, make it relative to project root
    if not path.is_absolute():
        path = project_root / path
    
    # Resolve any .. or . components
    return path.resolve()


def validate_path(path: Path, path_type: str, must_exist: bool = True, must_be_dir: bool = False) -> bool:
    """Validate that a path exists and has required properties."""
    if path is None:
        return False
    
    if must_exist and not path.exists():
        print(f"ERROR: {path_type} path does not exist: {path}", file=sys.stderr)
        return False
    
    if must_be_dir and path.exists() and not path.is_dir():
        print(f"ERROR: {path_type} path is not a directory: {path}", file=sys.stderr)
        return False
    
    if path.exists() and path.is_dir() and not os.access(path, os.R_OK):
        print(f"ERROR: {path_type} path is not readable: {path}", file=sys.stderr)
        return False
    
    return True


def update_config_paths(
    config: dict,
    chicken_root: Optional[Path],
    experiment_dir: Optional[Path],
    bpe_path: Optional[Path],
    project_root: Path
) -> dict:
    """Update config with resolved paths."""
    if 'paths' not in config:
        config['paths'] = {}
    
    # Update chicken_data_root
    if chicken_root:
        config['paths']['chicken_data_root'] = str(chicken_root)
    elif config['paths'].get('chicken_data_root') in ['<YOUR_DATASET_DIR>', None]:
        # Try environment variable
        env_path = os.getenv('CHICKEN_DATA_ROOT')
        if env_path:
            config['paths']['chicken_data_root'] = str(resolve_path(env_path, project_root))
        else:
            # Default to data/chicken-and-not-chicken
            default_dir = project_root / 'data' / 'chicken-and-not-chicken'
            if default_dir.exists():
                config['paths']['chicken_data_root'] = str(default_dir)
            else:
                raise ValueError("chicken_data_root not specified. Use --chicken-root or set CHICKEN_DATA_ROOT")
    
    # Update experiment_log_dir
    if experiment_dir:
        config['paths']['experiment_log_dir'] = str(experiment_dir)
    elif config['paths'].get('experiment_log_dir') in ['<YOUR_EXPERIMENT_LOG_DIR>', None]:
        # Try environment variable
        env_path = os.getenv('EXPERIMENT_LOG_DIR')
        if env_path:
            config['paths']['experiment_log_dir'] = str(resolve_path(env_path, project_root))
        else:
            # Default to experiments/logs
            default_dir = project_root / 'experiments' / 'logs'
            default_dir.mkdir(parents=True, exist_ok=True)
            config['paths']['experiment_log_dir'] = str(default_dir)
    
    # Update bpe_path
    if bpe_path:
        config['paths']['bpe_path'] = str(bpe_path)
    elif config['paths'].get('bpe_path') in ['<BPE_PATH>', None]:
        # Try environment variable
        env_path = os.getenv('BPE_PATH')
        if env_path:
            config['paths']['bpe_path'] = str(resolve_path(env_path, project_root))
        else:
            # Default to sam3 assets
            default_bpe = project_root / 'sam3' / 'sam3' / 'assets' / 'bpe_simple_vocab_16e6.txt.gz'
            if default_bpe.exists():
                config['paths']['bpe_path'] = str(default_bpe)
            else:
                raise ValueError(f"BPE path not found at default location: {default_bpe}")
    
    return config


def main() -> int:
    """Main function."""
    parser = argparse.ArgumentParser(
        description='Resolve and update config file paths for Chicken Detection training'
    )
    parser.add_argument(
        '--base-config',
        type=str,
        default='sam3/sam3/train/configs/chicken_detection/chicken_detection_train.yaml',
        help='Path to base config file (relative to project root)'
    )
    parser.add_argument(
        '--chicken-root',
        type=str,
        help='Path to Chicken Detection dataset root directory'
    )
    parser.add_argument(
        '--experiment-dir',
        type=str,
        help='Path to experiment log directory'
    )
    parser.add_argument(
        '--bpe-path',
        type=str,
        help='Path to BPE vocabulary file'
    )
    parser.add_argument(
        '--output',
        type=str,
        required=True,
        help='Output path for resolved config file'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be done without writing files'
    )
    
    args = parser.parse_args()
    
    project_root = get_project_root()
    
    # Load base config
    base_config_path = project_root / args.base_config
    try:
        config = load_base_config(base_config_path)
    except FileNotFoundError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1
    
    # Resolve paths
    chicken_root = resolve_path(args.chicken_root, project_root) if args.chicken_root else None
    experiment_dir = resolve_path(args.experiment_dir, project_root) if args.experiment_dir else None
    bpe_path = resolve_path(args.bpe_path, project_root) if args.bpe_path else None
    
    # Update config
    try:
        config = update_config_paths(
            config,
            chicken_root,
            experiment_dir,
            bpe_path,
            project_root
        )
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1
    
    # Validate paths
    chicken_root_path = Path(config['paths'].get('chicken_data_root', ''))
    if not validate_path(chicken_root_path, 'chicken_data_root', must_exist=True, must_be_dir=True):
        return 1
    
    # Check for required subdirectories
    for split in ['train', 'valid']:
        split_dir = chicken_root_path / split
        if not split_dir.exists():
            print(f"WARNING: {split} directory not found: {split_dir}", file=sys.stderr)
        ann_file = split_dir / '_annotations.coco.json'
        if not ann_file.exists():
            print(f"WARNING: Annotation file not found: {ann_file}", file=sys.stderr)
    
    bpe_path_obj = Path(config['paths'].get('bpe_path', ''))
    if not validate_path(bpe_path_obj, 'bpe_path', must_exist=True, must_be_dir=False):
        return 1
    
    # Write resolved config
    output_path = Path(args.output)
    if args.dry_run:
        print("DRY RUN: Would write resolved config to:", output_path)
        print("\nResolved paths:")
        print(f"  chicken_data_root: {config['paths'].get('chicken_data_root')}")
        print(f"  experiment_log_dir: {config['paths'].get('experiment_log_dir')}")
        print(f"  bpe_path: {config['paths'].get('bpe_path')}")
        return 0
    
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'w') as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
    
    print(f"Resolved config written to: {output_path}")
    print(f"  chicken_data_root: {config['paths'].get('chicken_data_root')}")
    print(f"  experiment_log_dir: {config['paths'].get('experiment_log_dir')}")
    print(f"  bpe_path: {config['paths'].get('bpe_path')}")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
