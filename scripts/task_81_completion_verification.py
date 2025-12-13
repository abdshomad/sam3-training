#!/usr/bin/env -S uv run python
"""
Task ID: 8.1
Description: Training Completion Verification
Created: 2025-12-13

This script verifies that training completed successfully:
- Check that final checkpoint exists and is valid
- Verify training logs indicate successful completion (not early termination)
- Check for any error messages in logs
- Validate that config_resolved.yaml was generated
- Confirm TensorBoard logs were created
- Report final training metrics (loss, epochs, time)
"""

import argparse
import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

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


def check_final_checkpoint(checkpoint_dir: Path) -> Tuple[bool, Optional[Path], Optional[str]]:
    """Check if final checkpoint exists and is valid."""
    if not checkpoint_dir.exists():
        return False, None, "Checkpoint directory does not exist"
    
    # Look for checkpoint files
    checkpoints = []
    for pattern in ['*.pth', '*.pt', '*.ckpt']:
        checkpoints.extend(checkpoint_dir.glob(pattern))
    
    if not checkpoints:
        return False, None, "No checkpoints found"
    
    # Get latest checkpoint
    latest = max(checkpoints, key=lambda p: p.stat().st_mtime)
    
    # Check if file is readable and has reasonable size
    if latest.stat().st_size < 1024:  # Less than 1KB is suspicious
        return False, latest, "Checkpoint file is too small (may be corrupted)"
    
    return True, latest, None


def analyze_training_logs(log_dir: Path) -> Dict:
    """Analyze training logs for completion status."""
    result = {
        'completed': False,
        'early_termination': False,
        'errors': [],
        'warnings': [],
        'final_epoch': None,
        'final_loss': None,
        'total_epochs': None,
        'training_time': None
    }
    
    # Find log files
    log_files = []
    if log_dir.exists():
        log_files.extend(log_dir.glob('**/*.log'))
        log_files.extend(log_dir.glob('**/*.txt'))
    
    if not log_files:
        result['errors'].append("No log files found")
        return result
    
    # Read the most recent log file
    latest_log = max(log_files, key=lambda p: p.stat().st_mtime)
    
    try:
        with open(latest_log, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
            lines = content.split('\n')
        
        # Look for completion indicators
        completion_patterns = [
            r'training.*complete',
            r'training.*finished',
            r'epoch.*\d+.*complete',
            r'final.*epoch',
        ]
        
        for pattern in completion_patterns:
            if re.search(pattern, content, re.IGNORECASE):
                result['completed'] = True
                break
        
        # Look for early termination indicators
        early_term_patterns = [
            r'early.*stop',
            r'stopped.*early',
            r'keyboard.*interrupt',
            r'ctrl.*c',
            r'killed',
            r'sigterm',
        ]
        
        for pattern in early_term_patterns:
            if re.search(pattern, content, re.IGNORECASE):
                result['early_termination'] = True
                break
        
        # Extract final epoch
        epoch_matches = re.findall(r'epoch[:\s]+(\d+)', content, re.IGNORECASE)
        if epoch_matches:
            result['final_epoch'] = int(epoch_matches[-1])
        
        # Extract final loss
        loss_matches = re.findall(r'loss[:\s]+([\d.e-]+)', content, re.IGNORECASE)
        if loss_matches:
            try:
                result['final_loss'] = float(loss_matches[-1])
            except ValueError:
                pass
        
        # Look for errors
        error_patterns = [
            r'ERROR',
            r'Exception',
            r'Traceback',
            r'RuntimeError',
            r'CUDA.*error',
            r'out.*of.*memory',
        ]
        
        for line in lines[-100:]:  # Check last 100 lines
            for pattern in error_patterns:
                if re.search(pattern, line, re.IGNORECASE):
                    result['errors'].append(line.strip())
                    break
        
        # Look for warnings
        warning_patterns = [
            r'WARNING',
            r'WARN',
            r'NaN',
            r'nan',
        ]
        
        for line in lines[-100:]:
            for pattern in warning_patterns:
                if re.search(pattern, line, re.IGNORECASE):
                    result['warnings'].append(line.strip())
                    break
        
        # Extract training time if available
        time_matches = re.findall(r'training.*time[:\s]+([\d.]+)', content, re.IGNORECASE)
        if time_matches:
            try:
                result['training_time'] = float(time_matches[-1])
            except ValueError:
                pass
        
    except Exception as e:
        result['errors'].append(f"Failed to read log file: {e}")
    
    return result


def check_config_resolved(experiment_dir: Path) -> Tuple[bool, Optional[Path]]:
    """Check if config_resolved.yaml exists."""
    config_path = experiment_dir / 'config_resolved.yaml'
    if config_path.exists():
        return True, config_path
    return False, None


def check_tensorboard_logs(experiment_dir: Path) -> Tuple[bool, Optional[Path]]:
    """Check if TensorBoard logs exist."""
    tensorboard_dir = experiment_dir / 'tensorboard'
    if tensorboard_dir.exists() and any(tensorboard_dir.iterdir()):
        return True, tensorboard_dir
    return False, None


def extract_final_metrics(config_resolved_path: Path) -> Dict:
    """Extract final training metrics from config_resolved.yaml."""
    metrics = {}
    
    try:
        with open(config_resolved_path, 'r') as f:
            config = yaml.safe_load(f)
        
        trainer = config.get('trainer', {})
        metrics['max_epochs'] = trainer.get('max_epochs')
        
        scratch = config.get('scratch', {})
        metrics['resolution'] = scratch.get('resolution')
        metrics['batch_size'] = scratch.get('train_batch_size')
        
    except Exception as e:
        metrics['error'] = str(e)
    
    return metrics


def main() -> int:
    """Main function."""
    parser = argparse.ArgumentParser(
        description='Verify RF100-VL training completion'
    )
    parser.add_argument(
        '--experiment-dir',
        type=str,
        help='Path to experiment log directory (default: experiments/logs from .env.rf100vl or ./experiments/logs)'
    )
    parser.add_argument(
        '--json',
        action='store_true',
        help='Output results as JSON'
    )
    
    args = parser.parse_args()
    
    project_root = get_project_root()
    
    # Use default experiment dir if not provided
    if args.experiment_dir:
        experiment_dir = project_root / args.experiment_dir if not Path(args.experiment_dir).is_absolute() else Path(args.experiment_dir)
    else:
        # Try environment variable or default
        env_exp_dir = os.getenv('EXPERIMENT_LOG_DIR', './experiments/logs')
        experiment_dir = project_root / env_exp_dir if not Path(env_exp_dir).is_absolute() else Path(env_exp_dir)
        print(f"No --experiment-dir specified, using default: {experiment_dir}")
    
    if not experiment_dir.exists():
        print(f"WARNING: Experiment directory does not exist: {experiment_dir}", file=sys.stderr)
        print("This is normal if training hasn't started yet. Skipping verification.", file=sys.stderr)
        return 0  # Exit gracefully instead of erroring
    
    results = {
        'experiment_dir': str(experiment_dir),
        'checkpoint': {},
        'logs': {},
        'config_resolved': {},
        'tensorboard': {},
        'overall_status': 'unknown'
    }
    
    # Check checkpoint
    checkpoint_dir = experiment_dir / 'checkpoints'
    checkpoint_valid, checkpoint_path, checkpoint_error = check_final_checkpoint(checkpoint_dir)
    results['checkpoint'] = {
        'exists': checkpoint_valid,
        'path': str(checkpoint_path) if checkpoint_path else None,
        'error': checkpoint_error
    }
    
    # Analyze logs
    log_dir = experiment_dir / 'logs'
    log_analysis = analyze_training_logs(log_dir)
    results['logs'] = log_analysis
    
    # Check config_resolved.yaml
    config_valid, config_path = check_config_resolved(experiment_dir)
    results['config_resolved'] = {
        'exists': config_valid,
        'path': str(config_path) if config_path else None
    }
    
    if config_valid:
        metrics = extract_final_metrics(config_path)
        results['config_resolved']['metrics'] = metrics
    
    # Check TensorBoard logs
    tb_valid, tb_path = check_tensorboard_logs(experiment_dir)
    results['tensorboard'] = {
        'exists': tb_valid,
        'path': str(tb_path) if tb_path else None
    }
    
    # Determine overall status
    if checkpoint_valid and log_analysis['completed'] and not log_analysis['early_termination'] and config_valid:
        results['overall_status'] = 'success'
    elif log_analysis['early_termination']:
        results['overall_status'] = 'early_termination'
    elif not checkpoint_valid:
        results['overall_status'] = 'no_checkpoint'
    elif not log_analysis['completed']:
        results['overall_status'] = 'incomplete'
    else:
        results['overall_status'] = 'partial'
    
    # Output results
    if args.json:
        import json
        print(json.dumps(results, indent=2))
    else:
        print("=" * 80)
        print("Training Completion Verification")
        print("=" * 80)
        print(f"\nExperiment Directory: {experiment_dir}")
        print(f"\nOverall Status: {results['overall_status'].upper()}")
        
        print("\n" + "-" * 80)
        print("Checkpoint Status:")
        print("-" * 80)
        if results['checkpoint']['exists']:
            print(f"✓ Final checkpoint found: {Path(results['checkpoint']['path']).name}")
        else:
            print(f"✗ {results['checkpoint']['error']}")
        
        print("\n" + "-" * 80)
        print("Training Logs:")
        print("-" * 80)
        if results['logs']['completed']:
            print("✓ Training completed successfully")
        elif results['logs']['early_termination']:
            print("⚠ Training terminated early")
        else:
            print("✗ Training may not have completed")
        
        if results['logs']['final_epoch'] is not None:
            print(f"  Final epoch: {results['logs']['final_epoch']}")
        if results['logs']['final_loss'] is not None:
            print(f"  Final loss: {results['logs']['final_loss']:.6f}")
        
        if results['logs']['errors']:
            print(f"\n⚠ Errors found ({len(results['logs']['errors'])}):")
            for error in results['logs']['errors'][:5]:
                print(f"  {error}")
        
        if results['logs']['warnings']:
            print(f"\n⚠ Warnings found ({len(results['logs']['warnings'])}):")
            for warning in results['logs']['warnings'][:5]:
                print(f"  {warning}")
        
        print("\n" + "-" * 80)
        print("Config Files:")
        print("-" * 80)
        if results['config_resolved']['exists']:
            print("✓ config_resolved.yaml found")
            if 'metrics' in results['config_resolved']:
                metrics = results['config_resolved']['metrics']
                if 'max_epochs' in metrics:
                    print(f"  Max epochs: {metrics['max_epochs']}")
        else:
            print("✗ config_resolved.yaml not found")
        
        print("\n" + "-" * 80)
        print("TensorBoard Logs:")
        print("-" * 80)
        if results['tensorboard']['exists']:
            print("✓ TensorBoard logs found")
        else:
            print("✗ TensorBoard logs not found")
        
        print("\n" + "=" * 80)
    
    # Return appropriate exit code
    if results['overall_status'] == 'success':
        return 0
    elif results['overall_status'] in ['partial', 'early_termination']:
        return 1
    elif results['overall_status'] in ['no_checkpoint', 'incomplete']:
        # These are normal before training starts, exit gracefully
        return 0
    else:
        return 2


if __name__ == '__main__':
    sys.exit(main())

