#!/usr/bin/env -S uv run python
"""
Task ID: 6.1
Description: Config Path Resolution Script
Created: 2025-12-13

This script resolves and updates config file paths (roboflow_vl_100_root, 
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

# Load environment variables from .env and .env.rf100vl files
project_root = Path(__file__).parent.parent
load_dotenv(project_root / '.env')
load_dotenv(project_root / '.env.rf100vl')  # RF100-VL specific settings


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
    roboflow_root: Optional[Path],
    experiment_dir: Optional[Path],
    bpe_path: Optional[Path],
    project_root: Path
) -> dict:
    """Update config with resolved paths."""
    if 'paths' not in config:
        config['paths'] = {}
    
    # Update roboflow_vl_100_root
    if roboflow_root:
        config['paths']['roboflow_vl_100_root'] = str(roboflow_root)
    elif config['paths'].get('roboflow_vl_100_root') in ['<YOUR_DATASET_DIR>', None]:
        # Try environment variable
        env_path = os.getenv('ROBOFLOW_VL_100_ROOT')
        if env_path:
            config['paths']['roboflow_vl_100_root'] = str(resolve_path(env_path, project_root))
        else:
            raise ValueError("roboflow_vl_100_root not specified. Use --roboflow-root or set ROBOFLOW_VL_100_ROOT")
    
    # Update experiment_log_dir
    if experiment_dir:
        config['paths']['experiment_log_dir'] = str(experiment_dir)
    elif config['paths'].get('experiment_log_dir') in ['<YOUR EXPERIMENET LOG_DIR>', None]:
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
        description='Resolve and update config file paths for RF100-VL training'
    )
    parser.add_argument(
        '--base-config',
        type=str,
        default='sam3/sam3/train/configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml',
        help='Path to base config file (relative to project root)'
    )
    parser.add_argument(
        '--roboflow-root',
        type=str,
        help='Path to Roboflow VL-100 dataset root directory'
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
        help='Output config file path (default: experiments/configs/resolved_config.yaml)'
    )
    parser.add_argument(
        '--skip-validation',
        action='store_true',
        help='Skip path validation (useful for cluster mode where paths exist on compute nodes)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be done without writing output file'
    )
    
    args = parser.parse_args()
    
    project_root = get_project_root()
    
    # Load base config
    base_config_path = project_root / args.base_config
    print(f"Loading base config from: {base_config_path}")
    config = load_base_config(base_config_path)
    
    # Resolve paths
    roboflow_root = resolve_path(args.roboflow_root, project_root) if args.roboflow_root else None
    experiment_dir = resolve_path(args.experiment_dir, project_root) if args.experiment_dir else None
    bpe_path = resolve_path(args.bpe_path, project_root) if args.bpe_path else None
    
    # Update config
    try:
        config = update_config_paths(config, roboflow_root, experiment_dir, bpe_path, project_root)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1
    
    # Validate paths
    if not args.skip_validation:
        print("\nValidating paths...")
        paths_valid = True
        
        roboflow_path = Path(config['paths']['roboflow_vl_100_root'])
        if not validate_path(roboflow_path, "roboflow_vl_100_root", must_exist=True, must_be_dir=True):
            paths_valid = False
        
        exp_dir = Path(config['paths']['experiment_log_dir'])
        if not validate_path(exp_dir, "experiment_log_dir", must_exist=False, must_be_dir=True):
            # Try to create if it doesn't exist
            try:
                exp_dir.mkdir(parents=True, exist_ok=True)
                print(f"Created experiment log directory: {exp_dir}")
            except Exception as e:
                print(f"ERROR: Cannot create experiment log directory: {e}", file=sys.stderr)
                paths_valid = False
        
        bpe_file = Path(config['paths']['bpe_path'])
        if not validate_path(bpe_file, "bpe_path", must_exist=True, must_be_dir=False):
            paths_valid = False
        
        if not paths_valid:
            print("\nERROR: Path validation failed. Fix the errors above and try again.", file=sys.stderr)
            return 1
        
        print("✓ All paths validated successfully")
    
    # Determine output path
    if args.output:
        output_path = resolve_path(args.output, project_root)
    else:
        output_dir = project_root / 'experiments' / 'configs'
        output_dir.mkdir(parents=True, exist_ok=True)
        output_path = output_dir / 'resolved_config.yaml'
    
    # Write output
    if args.dry_run:
        print("\n=== DRY RUN: Would write config to ===")
        print(f"Output path: {output_path}")
        print("\n=== Resolved paths ===")
        print(f"roboflow_vl_100_root: {config['paths']['roboflow_vl_100_root']}")
        print(f"experiment_log_dir: {config['paths']['experiment_log_dir']}")
        print(f"bpe_path: {config['paths']['bpe_path']}")
        return 0
    
    print(f"\nWriting resolved config to: {output_path}")
    with open(output_path, 'w') as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
    
    print("✓ Config path resolution completed successfully")
    print(f"\nResolved config saved to: {output_path}")
    print("\nResolved paths:")
    print(f"  roboflow_vl_100_root: {config['paths']['roboflow_vl_100_root']}")
    print(f"  experiment_log_dir: {config['paths']['experiment_log_dir']}")
    print(f"  bpe_path: {config['paths']['bpe_path']}")
    
    return 0


if __name__ == '__main__':
    sys.exit(main())

