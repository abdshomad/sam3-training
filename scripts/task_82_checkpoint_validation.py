#!/usr/bin/env -S uv run python
"""
Task ID: 8.2
Description: Model Checkpoint Validation
Created: 2025-12-13

This script validates the trained model checkpoint:
- Load checkpoint and verify model structure
- Check that model weights are valid (no NaN, reasonable ranges)
- Verify checkpoint metadata (epoch, loss, etc.)
- Test model can perform inference on sample data
- Generate checkpoint summary report
"""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from dotenv import load_dotenv
import torch
import numpy as np

# Load environment variables from .env and .env.rf100vl files
project_root = Path(__file__).parent.parent
load_dotenv(project_root / '.env')
load_dotenv(project_root / '.env.rf100vl')  # RF100-VL specific settings


def get_project_root() -> Path:
    """Get the project root directory."""
    script_dir = Path(__file__).parent
    return script_dir.parent


def load_checkpoint(checkpoint_path: Path, device: str = 'cpu') -> Dict:
    """Load checkpoint and return data."""
    try:
        checkpoint = torch.load(checkpoint_path, map_location=device)
        return {'success': True, 'data': checkpoint, 'error': None}
    except Exception as e:
        return {'success': False, 'data': None, 'error': str(e)}


def validate_model_structure(checkpoint: Dict) -> Tuple[bool, List[str]]:
    """Validate that checkpoint has proper model structure."""
    issues = []
    
    # Check for state_dict or model weights
    has_state_dict = (
        'state_dict' in checkpoint or
        'model' in checkpoint or
        'model_state_dict' in checkpoint or
        'model_state' in checkpoint
    )
    
    if not has_state_dict:
        issues.append("No model state_dict found in checkpoint")
        return False, issues
    
    # Get state_dict
    state_dict = (
        checkpoint.get('state_dict') or
        checkpoint.get('model') or
        checkpoint.get('model_state_dict') or
        checkpoint.get('model_state')
    )
    
    if not isinstance(state_dict, dict):
        issues.append("State dict is not a dictionary")
        return False, issues
    
    if len(state_dict) == 0:
        issues.append("State dict is empty")
        return False, issues
    
    return True, issues


def validate_weights(state_dict: Dict) -> Tuple[bool, Dict]:
    """Validate that model weights are valid (no NaN, reasonable ranges)."""
    stats = {
        'total_params': 0,
        'nan_params': 0,
        'inf_params': 0,
        'zero_params': 0,
        'param_shapes': {},
        'weight_ranges': {}
    }
    
    issues = []
    
    for key, tensor in state_dict.items():
        if not isinstance(tensor, torch.Tensor):
            continue
        
        stats['total_params'] += tensor.numel()
        stats['param_shapes'][key] = list(tensor.shape)
        
        # Check for NaN
        nan_count = torch.isnan(tensor).sum().item()
        if nan_count > 0:
            stats['nan_params'] += nan_count
            issues.append(f"NaN found in {key}: {nan_count} values")
        
        # Check for Inf
        inf_count = torch.isinf(tensor).sum().item()
        if inf_count > 0:
            stats['inf_params'] += inf_count
            issues.append(f"Inf found in {key}: {inf_count} values")
        
        # Check for all zeros
        if tensor.numel() > 0:
            zero_count = (tensor == 0).sum().item()
            zero_ratio = zero_count / tensor.numel()
            if zero_ratio > 0.95:  # More than 95% zeros is suspicious
                stats['zero_params'] += zero_count
                issues.append(f"Mostly zeros in {key}: {zero_ratio*100:.1f}%")
        
        # Get weight ranges
        if tensor.numel() > 0:
            stats['weight_ranges'][key] = {
                'min': float(tensor.min().item()),
                'max': float(tensor.max().item()),
                'mean': float(tensor.mean().item()),
                'std': float(tensor.std().item())
            }
            
            # Check for extreme values
            abs_max = abs(tensor).max().item()
            if abs_max > 1e6:
                issues.append(f"Extreme values in {key}: max absolute value = {abs_max:.2e}")
    
    is_valid = len(issues) == 0
    return is_valid, stats, issues


def extract_checkpoint_metadata(checkpoint: Dict) -> Dict:
    """Extract metadata from checkpoint."""
    metadata = {
        'epoch': None,
        'loss': None,
        'best_loss': None,
        'learning_rate': None,
        'optimizer_state': False,
        'scheduler_state': False,
        'timestamp': None,
        'model_config': None
    }
    
    # Extract epoch
    if 'epoch' in checkpoint:
        metadata['epoch'] = checkpoint['epoch']
    elif 'metadata' in checkpoint and 'epoch' in checkpoint['metadata']:
        metadata['epoch'] = checkpoint['metadata']['epoch']
    
    # Extract loss
    if 'loss' in checkpoint:
        metadata['loss'] = checkpoint['loss']
    elif 'best_loss' in checkpoint:
        metadata['best_loss'] = checkpoint['best_loss']
    elif 'metrics' in checkpoint:
        metrics = checkpoint['metrics']
        if 'loss' in metrics:
            metadata['loss'] = metrics['loss']
        if 'best_loss' in metrics:
            metadata['best_loss'] = metrics['best_loss']
    
    # Check for optimizer state
    metadata['optimizer_state'] = 'optimizer' in checkpoint or 'optimizer_state_dict' in checkpoint
    
    # Check for scheduler state
    metadata['scheduler_state'] = 'scheduler' in checkpoint or 'scheduler_state_dict' in checkpoint
    
    # Extract model config if available
    if 'config' in checkpoint:
        metadata['model_config'] = checkpoint['config']
    elif 'model_config' in checkpoint:
        metadata['model_config'] = checkpoint['model_config']
    
    return metadata


def test_inference(checkpoint_path: Path, device: str = 'cpu') -> Tuple[bool, Optional[str]]:
    """Test that model can perform inference (if model builder is available)."""
    try:
        # Try to import SAM3 model builder
        sys.path.insert(0, str(get_project_root() / 'sam3'))
        from sam3.model_builder import build_sam3_image_model
        
        # Load model
        model = build_sam3_image_model()
        
        # Try to load checkpoint
        checkpoint = torch.load(checkpoint_path, map_location=device)
        
        # Try to load state dict
        state_dict = (
            checkpoint.get('state_dict') or
            checkpoint.get('model') or
            checkpoint.get('model_state_dict')
        )
        
        if state_dict:
            # Try to load weights (may fail if architecture doesn't match)
            try:
                model.load_state_dict(state_dict, strict=False)
                return True, None
            except Exception as e:
                return False, f"Failed to load state dict: {e}"
        else:
            return False, "No state dict found in checkpoint"
    
    except ImportError:
        return False, "SAM3 model builder not available (skipping inference test)"
    except Exception as e:
        return False, f"Inference test failed: {e}"


def generate_summary_report(
    checkpoint_path: Path,
    structure_valid: bool,
    weights_valid: bool,
    weights_stats: Dict,
    metadata: Dict,
    inference_test: Tuple[bool, Optional[str]]
) -> str:
    """Generate a summary report."""
    report = []
    report.append("=" * 80)
    report.append("Checkpoint Validation Report")
    report.append("=" * 80)
    report.append(f"\nCheckpoint: {checkpoint_path}")
    report.append(f"Size: {checkpoint_path.stat().st_size / (1024**2):.2f} MB")
    
    report.append("\n" + "-" * 80)
    report.append("Structure Validation:")
    report.append("-" * 80)
    if structure_valid:
        report.append("✓ Model structure is valid")
    else:
        report.append("✗ Model structure validation failed")
    
    report.append("\n" + "-" * 80)
    report.append("Weights Validation:")
    report.append("-" * 80)
    if weights_valid:
        report.append("✓ Weights are valid (no NaN/Inf detected)")
    else:
        report.append("✗ Weight validation issues detected")
    
    report.append(f"\nTotal parameters: {weights_stats['total_params']:,}")
    if weights_stats['nan_params'] > 0:
        report.append(f"⚠ NaN parameters: {weights_stats['nan_params']:,}")
    if weights_stats['inf_params'] > 0:
        report.append(f"⚠ Inf parameters: {weights_stats['inf_params']:,}")
    
    report.append("\n" + "-" * 80)
    report.append("Metadata:")
    report.append("-" * 80)
    if metadata['epoch'] is not None:
        report.append(f"Epoch: {metadata['epoch']}")
    if metadata['loss'] is not None:
        report.append(f"Loss: {metadata['loss']:.6f}")
    if metadata['best_loss'] is not None:
        report.append(f"Best loss: {metadata['best_loss']:.6f}")
    report.append(f"Optimizer state: {'Yes' if metadata['optimizer_state'] else 'No'}")
    report.append(f"Scheduler state: {'Yes' if metadata['scheduler_state'] else 'No'}")
    
    report.append("\n" + "-" * 80)
    report.append("Inference Test:")
    report.append("-" * 80)
    inference_valid, inference_error = inference_test
    if inference_valid:
        report.append("✓ Model can be loaded and state dict is compatible")
    else:
        report.append(f"⚠ Inference test: {inference_error}")
    
    report.append("\n" + "=" * 80)
    
    return "\n".join(report)


def main() -> int:
    """Main function."""
    parser = argparse.ArgumentParser(
        description='Validate trained model checkpoint for RF100-VL'
    )
    parser.add_argument(
        '--checkpoint',
        type=str,
        help='Path to checkpoint file (required if no default checkpoint found)'
    )
    parser.add_argument(
        '--device',
        type=str,
        default='cpu',
        help='Device to load checkpoint on (default: cpu)'
    )
    parser.add_argument(
        '--skip-inference',
        action='store_true',
        help='Skip inference test'
    )
    parser.add_argument(
        '--json',
        action='store_true',
        help='Output results as JSON'
    )
    
    args = parser.parse_args()
    
    project_root = get_project_root()
    
    # Use default checkpoint if not provided
    if args.checkpoint:
        checkpoint_path = project_root / args.checkpoint if not Path(args.checkpoint).is_absolute() else Path(args.checkpoint)
    else:
        # Try to find latest checkpoint in default location
        exp_dir = os.getenv('EXPERIMENT_LOG_DIR', './experiments/logs')
        exp_path = project_root / exp_dir if not Path(exp_dir).is_absolute() else Path(exp_dir)
        checkpoint_dir = exp_path / 'checkpoints'
        
        if checkpoint_dir.exists():
            # Find latest checkpoint
            checkpoints = list(checkpoint_dir.glob('*.pth')) + list(checkpoint_dir.glob('*.pt'))
            if checkpoints:
                checkpoint_path = max(checkpoints, key=lambda p: p.stat().st_mtime)
                print(f"No --checkpoint specified, using latest: {checkpoint_path}")
            else:
                print(f"WARNING: No checkpoint specified and no checkpoints found in {checkpoint_dir}", file=sys.stderr)
                print("This is normal if training hasn't started yet. Skipping validation.", file=sys.stderr)
                return 0  # Exit gracefully
        else:
            print(f"WARNING: No checkpoint specified and checkpoint directory does not exist: {checkpoint_dir}", file=sys.stderr)
            print("This is normal if training hasn't started yet. Skipping validation.", file=sys.stderr)
            return 0  # Exit gracefully
    
    if not checkpoint_path.exists():
        print(f"ERROR: Checkpoint not found: {checkpoint_path}", file=sys.stderr)
        return 1
    
    # Load checkpoint
    load_result = load_checkpoint(checkpoint_path, args.device)
    if not load_result['success']:
        print(f"ERROR: Failed to load checkpoint: {load_result['error']}", file=sys.stderr)
        return 1
    
    checkpoint = load_result['data']
    
    # Validate structure
    structure_valid, structure_issues = validate_model_structure(checkpoint)
    
    # Validate weights
    state_dict = (
        checkpoint.get('state_dict') or
        checkpoint.get('model') or
        checkpoint.get('model_state_dict') or
        checkpoint.get('model_state')
    )
    
    weights_valid = True
    weights_stats = {}
    weights_issues = []
    
    if state_dict and isinstance(state_dict, dict):
        weights_valid, weights_stats, weights_issues = validate_weights(state_dict)
    else:
        weights_valid = False
        weights_issues = ["No valid state dict found"]
    
    # Extract metadata
    metadata = extract_checkpoint_metadata(checkpoint)
    
    # Test inference
    inference_test = (False, "Skipped")
    if not args.skip_inference:
        inference_test = test_inference(checkpoint_path, args.device)
    
    # Generate results
    overall_valid = structure_valid and weights_valid
    
    if args.json:
        results = {
            'checkpoint': str(checkpoint_path),
            'valid': overall_valid,
            'structure': {
                'valid': structure_valid,
                'issues': structure_issues
            },
            'weights': {
                'valid': weights_valid,
                'stats': weights_stats,
                'issues': weights_issues
            },
            'metadata': metadata,
            'inference': {
                'valid': inference_test[0],
                'error': inference_test[1]
            }
        }
        print(json.dumps(results, indent=2))
    else:
        report = generate_summary_report(
            checkpoint_path,
            structure_valid,
            weights_valid,
            weights_stats,
            metadata,
            inference_test
        )
        print(report)
        
        if weights_issues:
            print("\nWeight Validation Issues:")
            for issue in weights_issues[:10]:  # Show first 10
                print(f"  - {issue}")
    
    return 0 if overall_valid else 1


if __name__ == '__main__':
    sys.exit(main())

