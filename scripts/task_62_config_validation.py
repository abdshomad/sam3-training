#!/usr/bin/env -S uv run python
"""
Task ID: 6.2
Description: Config Validation for Training
Created: 2025-12-13

This script validates that the training config file has all required fields 
correctly set (paths exist, parameters reasonable, GPU requirements match resources).
"""

import argparse
import os
import sys
from pathlib import Path
from typing import Dict, List, Optional

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


def load_config(config_path: Path) -> dict:
    """Load the config YAML file."""
    if not config_path.exists():
        raise FileNotFoundError(f"Config file not found: {config_path}")
    
    with open(config_path, 'r') as f:
        return yaml.safe_load(f)


def check_path_exists(path_str: str, path_name: str, must_be_dir: bool = False) -> tuple[bool, Optional[str]]:
    """Check if a path exists and has required properties."""
    if not path_str:
        return False, f"{path_name} is not set"
    
    path = Path(path_str)
    if not path.exists():
        return False, f"{path_name} does not exist: {path}"
    
    if must_be_dir and not path.is_dir():
        return False, f"{path_name} is not a directory: {path}"
    
    if path.is_dir() and not os.access(path, os.R_OK):
        return False, f"{path_name} is not readable: {path}"
    
    if path.is_file() and not os.access(path, os.R_OK):
        return False, f"{path_name} is not readable: {path}"
    
    return True, None


def check_directory_writable(path_str: str, path_name: str) -> tuple[bool, Optional[str]]:
    """Check if a directory is writable."""
    if not path_str:
        return False, f"{path_name} is not set"
    
    path = Path(path_str)
    
    # Try to create if it doesn't exist
    if not path.exists():
        try:
            path.mkdir(parents=True, exist_ok=True)
        except Exception as e:
            return False, f"Cannot create {path_name}: {e}"
    
    if not path.is_dir():
        return False, f"{path_name} is not a directory: {path}"
    
    if not os.access(path, os.W_OK):
        return False, f"{path_name} is not writable: {path}"
    
    return True, None


def check_disk_space(path_str: str, min_gb: float = 10.0) -> tuple[bool, Optional[str]]:
    """Check if there's sufficient disk space (in GB)."""
    if not path_str:
        return False, "Path not set"
    
    path = Path(path_str)
    if not path.exists():
        # Check parent directory
        path = path.parent
    
    try:
        stat = os.statvfs(path)
        free_gb = (stat.f_bavail * stat.f_frsize) / (1024 ** 3)
        
        if free_gb < min_gb:
            return False, f"Insufficient disk space: {free_gb:.2f} GB available, need at least {min_gb} GB"
        
        return True, f"{free_gb:.2f} GB available"
    except Exception as e:
        return False, f"Cannot check disk space: {e}"


def validate_roboflow_dataset_structure(roboflow_root: str) -> tuple[bool, Optional[str], List[str]]:
    """Validate that roboflow_vl_100_root has proper dataset structure."""
    root_path = Path(roboflow_root)
    if not root_path.exists():
        return False, f"Roboflow root does not exist: {roboflow_root}", []
    
    # Check for at least one dataset subdirectory
    subdirs = [d for d in root_path.iterdir() if d.is_dir()]
    if not subdirs:
        return False, f"No dataset subdirectories found in {roboflow_root}", []
    
    # Check a few subdirectories for train/test/valid structure
    valid_datasets = []
    invalid_datasets = []
    
    for subdir in subdirs[:5]:  # Check first 5 datasets
        train_dir = subdir / 'train'
        test_dir = subdir / 'test'
        valid_dir = subdir / 'valid'
        
        has_train = train_dir.exists() and (train_dir / '_annotations.coco.json').exists()
        has_test = test_dir.exists() and (test_dir / '_annotations.coco.json').exists()
        has_valid = valid_dir.exists() and (valid_dir / '_annotations.coco.json').exists()
        
        if has_train or has_test or has_valid:
            valid_datasets.append(subdir.name)
        else:
            invalid_datasets.append(subdir.name)
    
    if not valid_datasets:
        return False, f"No valid dataset structures found in {roboflow_root}", []
    
    return True, f"Found {len(valid_datasets)} valid datasets (checked {len(subdirs)} total)", valid_datasets


def check_gpu_requirements(config: dict, available_gpus: int) -> tuple[bool, Optional[str]]:
    """Check if GPU requirements match available resources."""
    launcher = config.get('launcher', {})
    num_nodes = launcher.get('num_nodes', 1)
    gpus_per_node = launcher.get('gpus_per_node', 1)
    total_gpus_needed = num_nodes * gpus_per_node
    
    if total_gpus_needed > available_gpus:
        return False, f"Config requires {total_gpus_needed} GPUs ({num_nodes} nodes × {gpus_per_node} GPUs/node), but only {available_gpus} available"
    
    return True, f"GPU requirements OK: {total_gpus_needed} GPUs needed, {available_gpus} available"


def get_available_gpus() -> int:
    """Get the number of available GPUs."""
    try:
        import subprocess
        result = subprocess.run(['nvidia-smi', '--list-gpus'], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            return len(result.stdout.strip().split('\n')) if result.stdout.strip() else 0
    except Exception:
        pass
    return 0


def validate_training_parameters(config: dict) -> tuple[bool, List[str]]:
    """Validate that training parameters are reasonable."""
    issues = []
    
    scratch = config.get('scratch', {})
    trainer = config.get('trainer', {})
    
    # Check batch size
    batch_size = scratch.get('train_batch_size', 1)
    try:
        batch_size = int(batch_size) if isinstance(batch_size, (int, float, str)) else 1
        if batch_size < 1:
            issues.append(f"train_batch_size is {batch_size}, should be >= 1")
    except (ValueError, TypeError):
        # Skip if it's a Hydra interpolation string
        pass
    
    # Check learning rates (may be Hydra interpolation strings)
    lr_transformer = scratch.get('lr_transformer', 0)
    try:
        if isinstance(lr_transformer, (int, float)):
            if lr_transformer <= 0:
                issues.append(f"lr_transformer is {lr_transformer}, should be > 0")
            elif lr_transformer > 1.0:
                issues.append(f"lr_transformer is {lr_transformer}, seems very high (typical: 1e-4 to 1e-3)")
    except (ValueError, TypeError):
        # Skip if it's a Hydra interpolation string
        pass
    
    # Check epochs
    max_epochs = trainer.get('max_epochs', 0)
    try:
        max_epochs = int(max_epochs) if isinstance(max_epochs, (int, float, str)) else 0
        if max_epochs < 1:
            issues.append(f"max_epochs is {max_epochs}, should be >= 1")
        elif max_epochs > 1000:
            issues.append(f"max_epochs is {max_epochs}, seems very high")
    except (ValueError, TypeError):
        # Skip if it's a Hydra interpolation string
        pass
    
    # Check resolution
    resolution = scratch.get('resolution', 0)
    try:
        resolution = int(resolution) if isinstance(resolution, (int, float, str)) else 0
        if resolution < 224:
            issues.append(f"resolution is {resolution}, should be >= 224")
        elif resolution > 2048:
            issues.append(f"resolution is {resolution}, seems very high (may cause OOM)")
    except (ValueError, TypeError):
        # Skip if it's a Hydra interpolation string
        pass
    
    return len(issues) == 0, issues


def check_supercategory_set(config: dict) -> tuple[bool, Optional[str]]:
    """Check that supercategory is set or will be set via job array."""
    roboflow_train = config.get('roboflow_train', {})
    supercategory = roboflow_train.get('supercategory', '')
    
    # Check if it uses job array syntax
    if '${' in str(supercategory) and 'submitit.job_array.task_index' in str(supercategory):
        return True, "Supercategory will be set via job array"
    
    # Check if it's a specific supercategory
    if supercategory and supercategory not in ['<YOUR_SUPERCATEGORY>', '']:
        return True, f"Supercategory is set to: {supercategory}"
    
    return False, "Supercategory is not set and not using job array"


def main() -> int:
    """Main function."""
    parser = argparse.ArgumentParser(
        description='Validate training config file for RF100-VL training'
    )
    parser.add_argument(
        '--config',
        type=str,
        help='Path to config file to validate (default: experiments/configs/resolved_config.yaml)'
    )
    parser.add_argument(
        '--skip-gpu-check',
        action='store_true',
        help='Skip GPU availability check'
    )
    parser.add_argument(
        '--skip-disk-space-check',
        action='store_true',
        help='Skip disk space check'
    )
    parser.add_argument(
        '--min-disk-space-gb',
        type=float,
        default=10.0,
        help='Minimum disk space required in GB (default: 10.0)'
    )
    
    args = parser.parse_args()
    
    project_root = get_project_root()
    
    # Use default config if not provided
    if args.config:
        config_path = project_root / args.config if not Path(args.config).is_absolute() else Path(args.config)
    else:
        # Default to the resolved config created by task_61
        default_config = project_root / 'experiments' / 'configs' / 'resolved_config.yaml'
        if default_config.exists():
            config_path = default_config
            print(f"No --config specified, using default: {config_path}")
        else:
            print(f"ERROR: No config file specified and default not found: {default_config}", file=sys.stderr)
            print("Please specify --config or run task_61_config_path_resolution.sh first", file=sys.stderr)
            return 1
    
    print(f"Validating config: {config_path}")
    
    # Load config
    try:
        config = load_config(config_path)
    except Exception as e:
        print(f"ERROR: Failed to load config: {e}", file=sys.stderr)
        return 1
    
    # Validate paths section
    print("\n=== Validating Paths ===")
    paths = config.get('paths', {})
    all_valid = True
    
    # Check roboflow_vl_100_root
    roboflow_root = paths.get('roboflow_vl_100_root', '')
    valid, error = check_path_exists(roboflow_root, 'roboflow_vl_100_root', must_be_dir=True)
    if valid:
        print(f"✓ roboflow_vl_100_root: {roboflow_root}")
        # Validate dataset structure
        struct_valid, struct_msg, datasets = validate_roboflow_dataset_structure(roboflow_root)
        if struct_valid:
            print(f"  {struct_msg}")
        else:
            print(f"  WARNING: {struct_msg}")
    else:
        print(f"✗ roboflow_vl_100_root: {error}")
        all_valid = False
    
    # Check experiment_log_dir
    exp_dir = paths.get('experiment_log_dir', '')
    valid, error = check_directory_writable(exp_dir, 'experiment_log_dir')
    if valid:
        print(f"✓ experiment_log_dir: {exp_dir}")
        if not args.skip_disk_space_check:
            space_valid, space_msg = check_disk_space(exp_dir, args.min_disk_space_gb)
            if space_valid:
                print(f"  Disk space: {space_msg}")
            else:
                print(f"  WARNING: {space_msg}")
    else:
        print(f"✗ experiment_log_dir: {error}")
        all_valid = False
    
    # Check bpe_path
    bpe_path = paths.get('bpe_path', '')
    valid, error = check_path_exists(bpe_path, 'bpe_path', must_be_dir=False)
    if valid:
        print(f"✓ bpe_path: {bpe_path}")
    else:
        print(f"✗ bpe_path: {error}")
        all_valid = False
    
    # Check supercategory
    print("\n=== Validating Training Configuration ===")
    supercat_valid, supercat_msg = check_supercategory_set(config)
    if supercat_valid:
        print(f"✓ {supercat_msg}")
    else:
        print(f"✗ {supercat_msg}")
        all_valid = False
    
    # Validate training parameters
    params_valid, param_issues = validate_training_parameters(config)
    if params_valid:
        print("✓ Training parameters are reasonable")
    else:
        print("✗ Training parameter issues:")
        for issue in param_issues:
            print(f"  - {issue}")
        all_valid = False
    
    # Check GPU requirements
    if not args.skip_gpu_check:
        print("\n=== Validating GPU Requirements ===")
        available_gpus = get_available_gpus()
        if available_gpus > 0:
            gpu_valid, gpu_msg = check_gpu_requirements(config, available_gpus)
            if gpu_valid:
                print(f"✓ {gpu_msg}")
            else:
                print(f"✗ {gpu_msg}")
                all_valid = False
        else:
            print("⚠ No GPUs detected (nvidia-smi not available or no GPUs)")
            print("  Skipping GPU requirement check")
    
    # Summary
    print("\n=== Validation Summary ===")
    if all_valid:
        print("✓ All validations passed!")
        return 0
    else:
        print("✗ Some validations failed. Please fix the issues above.")
        return 1


if __name__ == '__main__':
    sys.exit(main())

