#!/usr/bin/env -S uv run python
"""
Task ID: 7.3
Description: Checkpoint Management
Created: 2025-12-13

This script implements checkpoint management:
- Verify checkpoints are being saved correctly
- Monitor checkpoint directory size
- Implement checkpoint cleanup strategy (keep only last N checkpoints)
- Validate checkpoint integrity (can be loaded)
- Track training progress (epochs completed, best metrics)
"""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from dotenv import load_dotenv
import torch

# Load environment variables from .env and .env.rf100vl files
project_root = Path(__file__).parent.parent
load_dotenv(project_root / '.env')
load_dotenv(project_root / '.env.rf100vl')  # RF100-VL specific settings


def get_project_root() -> Path:
    """Get the project root directory."""
    script_dir = Path(__file__).parent
    return script_dir.parent


def list_checkpoints(checkpoint_dir: Path) -> List[Path]:
    """List all checkpoint files in directory."""
    checkpoints = []
    for pattern in ['*.pth', '*.pt', '*.ckpt']:
        checkpoints.extend(checkpoint_dir.glob(pattern))
    return sorted(checkpoints, key=lambda p: p.stat().st_mtime)


def get_checkpoint_info(checkpoint_path: Path) -> Dict:
    """Get information about a checkpoint file."""
    info = {
        'path': str(checkpoint_path),
        'name': checkpoint_path.name,
        'size_mb': checkpoint_path.stat().st_size / (1024 * 1024),
        'mtime': checkpoint_path.stat().st_mtime,
        'epoch': None,
        'loss': None,
        'valid': False,
        'error': None
    }
    
    # Try to load checkpoint and extract metadata
    try:
        checkpoint = torch.load(checkpoint_path, map_location='cpu')
        
        # Try to extract epoch
        if isinstance(checkpoint, dict):
            if 'epoch' in checkpoint:
                info['epoch'] = checkpoint['epoch']
            elif 'state_dict' in checkpoint and 'epoch' in checkpoint.get('metadata', {}):
                info['epoch'] = checkpoint['metadata']['epoch']
            
            # Try to extract loss
            if 'loss' in checkpoint:
                info['loss'] = checkpoint['loss']
            elif 'best_loss' in checkpoint:
                info['loss'] = checkpoint['best_loss']
            elif 'metrics' in checkpoint and 'loss' in checkpoint['metrics']:
                info['loss'] = checkpoint['metrics']['loss']
        
        info['valid'] = True
    except Exception as e:
        info['error'] = str(e)
        info['valid'] = False
    
    return info


def validate_checkpoint_integrity(checkpoint_path: Path) -> Tuple[bool, Optional[str]]:
    """Validate that a checkpoint can be loaded and has valid structure."""
    try:
        checkpoint = torch.load(checkpoint_path, map_location='cpu')
        
        if not isinstance(checkpoint, dict):
            return False, "Checkpoint is not a dictionary"
        
        # Check for state_dict or model weights
        has_state_dict = 'state_dict' in checkpoint or 'model' in checkpoint or 'model_state_dict' in checkpoint
        if not has_state_dict:
            return False, "Checkpoint does not contain model state_dict"
        
        # Check for NaN or Inf in weights
        state_dict = checkpoint.get('state_dict') or checkpoint.get('model') or checkpoint.get('model_state_dict')
        if isinstance(state_dict, dict):
            for key, tensor in state_dict.items():
                if isinstance(tensor, torch.Tensor):
                    if torch.isnan(tensor).any():
                        return False, f"NaN found in {key}"
                    if torch.isinf(tensor).any():
                        return False, f"Inf found in {key}"
        
        return True, None
    except Exception as e:
        return False, f"Failed to load checkpoint: {e}"


def cleanup_checkpoints(
    checkpoint_dir: Path,
    keep_last_n: int = 5,
    dry_run: bool = False
) -> Tuple[List[Path], List[Path]]:
    """Clean up old checkpoints, keeping only the last N."""
    checkpoints = list_checkpoints(checkpoint_dir)
    
    if len(checkpoints) <= keep_last_n:
        return checkpoints, []
    
    # Sort by modification time (newest first)
    checkpoints_sorted = sorted(checkpoints, key=lambda p: p.stat().st_mtime, reverse=True)
    
    to_keep = checkpoints_sorted[:keep_last_n]
    to_remove = checkpoints_sorted[keep_last_n:]
    
    if not dry_run:
        for checkpoint in to_remove:
            try:
                checkpoint.unlink()
            except Exception as e:
                print(f"WARNING: Failed to remove {checkpoint}: {e}", file=sys.stderr)
    
    return to_keep, to_remove


def get_checkpoint_directory_size(checkpoint_dir: Path) -> float:
    """Get total size of checkpoint directory in MB."""
    total_size = 0
    for checkpoint in list_checkpoints(checkpoint_dir):
        total_size += checkpoint.stat().st_size
    return total_size / (1024 * 1024)


def track_training_progress(checkpoint_dir: Path) -> Dict:
    """Track training progress from checkpoints."""
    checkpoints = list_checkpoints(checkpoint_dir)
    
    if not checkpoints:
        return {
            'checkpoints_found': 0,
            'latest_epoch': None,
            'best_loss': None,
            'latest_checkpoint': None
        }
    
    latest_checkpoint = max(checkpoints, key=lambda p: p.stat().st_mtime)
    info = get_checkpoint_info(latest_checkpoint)
    
    # Find best checkpoint (lowest loss)
    best_checkpoint = None
    best_loss = float('inf')
    
    for checkpoint in checkpoints:
        cp_info = get_checkpoint_info(checkpoint)
        if cp_info['valid'] and cp_info['loss'] is not None:
            if cp_info['loss'] < best_loss:
                best_loss = cp_info['loss']
                best_checkpoint = checkpoint
    
    return {
        'checkpoints_found': len(checkpoints),
        'latest_epoch': info['epoch'],
        'best_loss': best_loss if best_loss != float('inf') else None,
        'latest_checkpoint': str(latest_checkpoint),
        'best_checkpoint': str(best_checkpoint) if best_checkpoint else None
    }


def main() -> int:
    """Main function."""
    parser = argparse.ArgumentParser(
        description='Manage checkpoints for RF100-VL training'
    )
    parser.add_argument(
        '--checkpoint-dir',
        type=str,
        help='Path to checkpoint directory (default: experiments/logs/checkpoints or from EXPERIMENT_LOG_DIR)'
    )
    parser.add_argument(
        '--list',
        action='store_true',
        help='List all checkpoints with information'
    )
    parser.add_argument(
        '--validate',
        type=str,
        help='Validate a specific checkpoint file'
    )
    parser.add_argument(
        '--validate-all',
        action='store_true',
        help='Validate all checkpoints'
    )
    parser.add_argument(
        '--cleanup',
        action='store_true',
        help='Clean up old checkpoints (keep only last N)'
    )
    parser.add_argument(
        '--keep-last-n',
        type=int,
        default=5,
        help='Number of checkpoints to keep when cleaning up (default: 5)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be done without actually doing it'
    )
    parser.add_argument(
        '--progress',
        action='store_true',
        help='Show training progress summary'
    )
    parser.add_argument(
        '--size',
        action='store_true',
        help='Show checkpoint directory size'
    )
    
    args = parser.parse_args()
    
    project_root = get_project_root()
    
    # Use default checkpoint dir if not provided
    if args.checkpoint_dir:
        checkpoint_dir = project_root / args.checkpoint_dir if not Path(args.checkpoint_dir).is_absolute() else Path(args.checkpoint_dir)
    else:
        # Try to find default checkpoint directory
        exp_dir = os.getenv('EXPERIMENT_LOG_DIR', './experiments/logs')
        exp_path = project_root / exp_dir if not Path(exp_dir).is_absolute() else Path(exp_dir)
        checkpoint_dir = exp_path / 'checkpoints'
        print(f"No --checkpoint-dir specified, using default: {checkpoint_dir}")
    
    if not checkpoint_dir.exists():
        print(f"WARNING: Checkpoint directory does not exist: {checkpoint_dir}", file=sys.stderr)
        print("This is normal if training hasn't started yet. No checkpoints to manage.", file=sys.stderr)
        return 0  # Exit gracefully instead of erroring
    
    # List checkpoints
    if args.list:
        checkpoints = list_checkpoints(checkpoint_dir)
        print(f"\nFound {len(checkpoints)} checkpoints:")
        print("=" * 80)
        for checkpoint in checkpoints:
            info = get_checkpoint_info(checkpoint)
            print(f"\n{info['name']}:")
            print(f"  Size: {info['size_mb']:.2f} MB")
            print(f"  Valid: {info['valid']}")
            if info['epoch'] is not None:
                print(f"  Epoch: {info['epoch']}")
            if info['loss'] is not None:
                print(f"  Loss: {info['loss']:.6f}")
            if info['error']:
                print(f"  Error: {info['error']}")
    
    # Validate specific checkpoint
    if args.validate:
        checkpoint_path = checkpoint_dir / args.validate if not Path(args.validate).is_absolute() else Path(args.validate)
        if not checkpoint_path.exists():
            print(f"ERROR: Checkpoint not found: {checkpoint_path}", file=sys.stderr)
            return 1
        
        valid, error = validate_checkpoint_integrity(checkpoint_path)
        if valid:
            print(f"✓ Checkpoint is valid: {checkpoint_path}")
        else:
            print(f"✗ Checkpoint is invalid: {checkpoint_path}")
            print(f"  Error: {error}")
            return 1
    
    # Validate all checkpoints
    if args.validate_all:
        checkpoints = list_checkpoints(checkpoint_dir)
        print(f"\nValidating {len(checkpoints)} checkpoints...")
        print("=" * 80)
        
        valid_count = 0
        invalid_count = 0
        
        for checkpoint in checkpoints:
            valid, error = validate_checkpoint_integrity(checkpoint)
            if valid:
                print(f"✓ {checkpoint.name}")
                valid_count += 1
            else:
                print(f"✗ {checkpoint.name}: {error}")
                invalid_count += 1
        
        print(f"\nSummary: {valid_count} valid, {invalid_count} invalid")
        
        if invalid_count > 0:
            return 1
    
    # Cleanup checkpoints
    if args.cleanup:
        to_keep, to_remove = cleanup_checkpoints(checkpoint_dir, args.keep_last_n, args.dry_run)
        
        print(f"\nCheckpoint cleanup:")
        print(f"  Total checkpoints: {len(to_keep) + len(to_remove)}")
        print(f"  Keeping: {len(to_keep)}")
        print(f"  Removing: {len(to_remove)}")
        
        if args.dry_run:
            print("\nWould remove:")
            for checkpoint in to_remove:
                info = get_checkpoint_info(checkpoint)
                print(f"  {checkpoint.name} ({info['size_mb']:.2f} MB)")
        else:
            if to_remove:
                print("\nRemoved:")
                for checkpoint in to_remove:
                    info = get_checkpoint_info(checkpoint)
                    print(f"  {checkpoint.name} ({info['size_mb']:.2f} MB)")
                total_freed = sum(get_checkpoint_info(cp)['size_mb'] for cp in to_remove)
                print(f"\nTotal space freed: {total_freed:.2f} MB")
    
    # Show progress
    if args.progress:
        progress = track_training_progress(checkpoint_dir)
        print("\nTraining Progress:")
        print("=" * 80)
        print(f"Checkpoints found: {progress['checkpoints_found']}")
        if progress['latest_epoch'] is not None:
            print(f"Latest epoch: {progress['latest_epoch']}")
        if progress['best_loss'] is not None:
            print(f"Best loss: {progress['best_loss']:.6f}")
        if progress['latest_checkpoint']:
            print(f"Latest checkpoint: {Path(progress['latest_checkpoint']).name}")
        if progress['best_checkpoint']:
            print(f"Best checkpoint: {Path(progress['best_checkpoint']).name}")
    
    # Show size
    if args.size:
        total_size = get_checkpoint_directory_size(checkpoint_dir)
        print(f"\nCheckpoint directory size: {total_size:.2f} MB")
    
    # If no action specified, show summary
    if not any([args.list, args.validate, args.validate_all, args.cleanup, args.progress, args.size]):
        checkpoints = list_checkpoints(checkpoint_dir)
        progress = track_training_progress(checkpoint_dir)
        total_size = get_checkpoint_directory_size(checkpoint_dir)
        
        print(f"\nCheckpoint Summary:")
        print("=" * 80)
        print(f"Total checkpoints: {len(checkpoints)}")
        print(f"Total size: {total_size:.2f} MB")
        if progress['latest_epoch'] is not None:
            print(f"Latest epoch: {progress['latest_epoch']}")
        if progress['best_loss'] is not None:
            print(f"Best loss: {progress['best_loss']:.6f}")
    
    return 0


if __name__ == '__main__':
    sys.exit(main())

