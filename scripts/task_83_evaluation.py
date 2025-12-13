#!/usr/bin/env -S uv run python
"""
Task ID: 8.3
Description: Evaluation Script
Created: 2025-12-13

This script runs evaluation on trained model:
- Use roboflow_v100_eval.yaml config
- Load trained checkpoint
- Run evaluation on test set
- Generate evaluation metrics report
- Compare with baseline/pretrained model if available
"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Dict, Optional

from dotenv import load_dotenv

# Load environment variables from .env and .env.rf100vl files
project_root = Path(__file__).parent.parent
load_dotenv(project_root / '.env')
load_dotenv(project_root / '.env.rf100vl')  # RF100-VL specific settings


def get_project_root() -> Path:
    """Get the project root directory."""
    script_dir = Path(__file__).parent
    return script_dir.parent


def resolve_eval_config(
    base_config: str,
    checkpoint_path: str,
    experiment_dir: str,
    roboflow_root: Optional[str] = None
) -> Path:
    """Resolve and prepare evaluation config."""
    project_root = get_project_root()
    
    # Load base eval config
    eval_config_path = project_root / base_config
    if not eval_config_path.exists():
        raise FileNotFoundError(f"Eval config not found: {eval_config_path}")
    
    import yaml
    with open(eval_config_path, 'r') as f:
        config = yaml.safe_load(f)
    
    # Update paths
    if 'paths' not in config:
        config['paths'] = {}
    
    # Set checkpoint path
    config['paths']['checkpoint_path'] = checkpoint_path
    
    # Set experiment dir
    if experiment_dir:
        config['paths']['base_experiment_log_dir'] = experiment_dir
    
    # Set roboflow root if provided
    if roboflow_root:
        config['paths']['roboflow_vl_100_root'] = roboflow_root
    
    # Create resolved eval config
    resolved_dir = project_root / 'experiments' / 'configs'
    resolved_dir.mkdir(parents=True, exist_ok=True)
    
    resolved_config = resolved_dir / 'eval_config_resolved.yaml'
    with open(resolved_config, 'w') as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
    
    return resolved_config


def run_evaluation(
    config_path: Path,
    mode: str = 'local',
    num_gpus: int = 1,
    dry_run: bool = False
) -> Dict:
    """Run evaluation using the training script."""
    project_root = get_project_root()
    
    # Build command
    cmd = [
        'python', '-m', 'sam3.train.train',
        '-c', str(config_path),
        '--use-cluster', '1' if mode == 'cluster' else '0',
    ]
    
    if num_gpus:
        cmd.extend(['--num-gpus', str(num_gpus)])
    
    if dry_run:
        print(f"Would run: {' '.join(cmd)}")
        return {'success': True, 'output': 'Dry run', 'error': None}
    
    # Run evaluation
    try:
        result = subprocess.run(
            cmd,
            cwd=project_root,
            capture_output=True,
            text=True,
            timeout=3600  # 1 hour timeout
        )
        
        return {
            'success': result.returncode == 0,
            'output': result.stdout,
            'error': result.stderr if result.returncode != 0 else None,
            'returncode': result.returncode
        }
    except subprocess.TimeoutExpired:
        return {
            'success': False,
            'output': None,
            'error': 'Evaluation timed out after 1 hour'
        }
    except Exception as e:
        return {
            'success': False,
            'output': None,
            'error': str(e)
        }


def extract_evaluation_metrics(experiment_dir: Path) -> Dict:
    """Extract evaluation metrics from experiment directory."""
    metrics = {}
    
    # Look for evaluation results
    # Common locations: val_stats.json, results.json, metrics.json
    result_files = [
        experiment_dir / 'val_stats.json',
        experiment_dir / 'results.json',
        experiment_dir / 'metrics.json',
        experiment_dir / 'eval_results.json',
    ]
    
    for result_file in result_files:
        if result_file.exists():
            try:
                with open(result_file, 'r') as f:
                    metrics = json.load(f)
                break
            except Exception:
                continue
    
    # Also check subdirectories
    if not metrics:
        for subdir in experiment_dir.iterdir():
            if subdir.is_dir():
                for result_file in result_files:
                    check_file = subdir / result_file.name
                    if check_file.exists():
                        try:
                            with open(check_file, 'r') as f:
                                metrics = json.load(f)
                            break
                        except Exception:
                            continue
                if metrics:
                    break
    
    return metrics


def generate_evaluation_report(
    checkpoint_path: Path,
    metrics: Dict,
    eval_result: Dict
) -> str:
    """Generate evaluation report."""
    report = []
    report.append("=" * 80)
    report.append("Evaluation Report")
    report.append("=" * 80)
    report.append(f"\nCheckpoint: {checkpoint_path}")
    
    report.append("\n" + "-" * 80)
    report.append("Evaluation Status:")
    report.append("-" * 80)
    if eval_result['success']:
        report.append("✓ Evaluation completed successfully")
    else:
        report.append("✗ Evaluation failed")
        if eval_result['error']:
            report.append(f"  Error: {eval_result['error']}")
    
    report.append("\n" + "-" * 80)
    report.append("Metrics:")
    report.append("-" * 80)
    
    if metrics:
        # Look for common metrics
        metric_keys = [
            'AP', 'mAP', 'AP50', 'AP75',
            'bbox_AP', 'bbox_mAP',
            'coco_eval_bbox_AP',
            'precision', 'recall',
            'f1_score', 'f1'
        ]
        
        for key in metric_keys:
            if key in metrics:
                report.append(f"{key}: {metrics[key]}")
        
        # If no common metrics found, show all
        if not any(key in metrics for key in metric_keys):
            for key, value in list(metrics.items())[:20]:  # Show first 20
                report.append(f"{key}: {value}")
    else:
        report.append("No metrics found in results")
    
    report.append("\n" + "=" * 80)
    
    return "\n".join(report)


def main() -> int:
    """Main function."""
    parser = argparse.ArgumentParser(
        description='Run evaluation on trained RF100-VL model'
    )
    parser.add_argument(
        '--checkpoint',
        type=str,
        help='Path to trained checkpoint file (required if no default checkpoint found)'
    )
    parser.add_argument(
        '--experiment-dir',
        type=str,
        help='Path to experiment directory (for output)'
    )
    parser.add_argument(
        '--roboflow-root',
        type=str,
        help='Path to Roboflow dataset root'
    )
    parser.add_argument(
        '--eval-config',
        type=str,
        default='sam3/sam3/train/configs/roboflow_v100/roboflow_v100_eval.yaml',
        help='Path to evaluation config file'
    )
    parser.add_argument(
        '--mode',
        type=str,
        default='local',
        choices=['local', 'cluster'],
        help='Execution mode (default: local)'
    )
    parser.add_argument(
        '--num-gpus',
        type=int,
        default=1,
        help='Number of GPUs (default: 1)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be done without executing'
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
                print("This is normal if training hasn't started yet. Skipping evaluation.", file=sys.stderr)
                return 0  # Exit gracefully
        else:
            print(f"WARNING: No checkpoint specified and checkpoint directory does not exist: {checkpoint_dir}", file=sys.stderr)
            print("This is normal if training hasn't started yet. Skipping evaluation.", file=sys.stderr)
            return 0  # Exit gracefully
    
    if not checkpoint_path.exists():
        print(f"ERROR: Checkpoint not found: {checkpoint_path}", file=sys.stderr)
        return 1
    
    # Resolve experiment dir
    if args.experiment_dir:
        experiment_dir = project_root / args.experiment_dir if not Path(args.experiment_dir).is_absolute() else Path(args.experiment_dir)
    else:
        # Try to infer from checkpoint path
        experiment_dir = checkpoint_path.parent.parent
        if not experiment_dir.exists():
            experiment_dir = project_root / 'experiments' / 'logs'
            experiment_dir.mkdir(parents=True, exist_ok=True)
    
    # Resolve eval config
    try:
        resolved_config = resolve_eval_config(
            args.eval_config,
            str(checkpoint_path),
            str(experiment_dir),
            args.roboflow_root
        )
        print(f"Resolved eval config: {resolved_config}")
    except Exception as e:
        print(f"ERROR: Failed to resolve eval config: {e}", file=sys.stderr)
        return 1
    
    # Run evaluation
    print("\nRunning evaluation...")
    eval_result = run_evaluation(
        resolved_config,
        args.mode,
        args.num_gpus,
        args.dry_run
    )
    
    # Extract metrics
    metrics = {}
    if eval_result['success'] and not args.dry_run:
        metrics = extract_evaluation_metrics(experiment_dir)
    
    # Generate report
    if args.json:
        results = {
            'checkpoint': str(checkpoint_path),
            'experiment_dir': str(experiment_dir),
            'evaluation': eval_result,
            'metrics': metrics
        }
        print(json.dumps(results, indent=2))
    else:
        report = generate_evaluation_report(
            checkpoint_path,
            metrics,
            eval_result
        )
        print("\n" + report)
    
    return 0 if eval_result['success'] else 1


if __name__ == '__main__':
    sys.exit(main())

