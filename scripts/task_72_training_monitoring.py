#!/usr/bin/env -S uv run python
"""
Task ID: 7.2
Description: Training Progress Monitoring
Created: 2025-12-13

This script sets up real-time monitoring during training:
- Launch TensorBoard automatically in background (or provide command)
- Monitor GPU utilization and memory usage
- Track training metrics (loss, learning rate, etc.)
- Check for training errors or warnings in logs
- Provide periodic status updates
- Alert on critical issues (OOM, NaN losses, etc.)
"""

import argparse
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from dotenv import load_dotenv

# Load environment variables from .env and .env.rf100vl files
project_root = Path(__file__).parent.parent
load_dotenv(project_root / '.env')
load_dotenv(project_root / '.env.rf100vl')  # RF100-VL specific settings


def get_project_root() -> Path:
    """Get the project root directory."""
    script_dir = Path(__file__).parent
    return script_dir.parent


def check_gpu_usage() -> Dict[str, any]:
    """Check GPU utilization and memory usage."""
    try:
        result = subprocess.run(
            ['nvidia-smi', '--query-gpu=index,name,utilization.gpu,memory.used,memory.total,temperature.gpu', '--format=csv,noheader,nounits'],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        if result.returncode != 0:
            return {'available': False, 'error': 'nvidia-smi failed'}
        
        gpus = []
        for line in result.stdout.strip().split('\n'):
            if not line.strip():
                continue
            parts = [p.strip() for p in line.split(',')]
            if len(parts) >= 6:
                gpus.append({
                    'index': parts[0],
                    'name': parts[1],
                    'utilization': int(parts[2]),
                    'memory_used_mb': int(parts[3]),
                    'memory_total_mb': int(parts[4]),
                    'temperature': int(parts[5])
                })
        
        return {'available': True, 'gpus': gpus}
    except FileNotFoundError:
        return {'available': False, 'error': 'nvidia-smi not found'}
    except Exception as e:
        return {'available': False, 'error': str(e)}


def check_tensorboard_logs(experiment_dir: Path) -> Optional[Path]:
    """Check if TensorBoard logs exist."""
    tensorboard_dir = experiment_dir / 'tensorboard'
    if tensorboard_dir.exists() and any(tensorboard_dir.iterdir()):
        return tensorboard_dir
    return None


def parse_training_log(log_path: Path, last_position: int = 0) -> Tuple[int, List[str], List[str]]:
    """Parse training log for errors and warnings."""
    errors = []
    warnings = []
    
    try:
        with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
            f.seek(last_position)
            new_content = f.read()
            last_position = f.tell()
            
            # Look for errors
            error_patterns = [
                r'ERROR',
                r'Exception',
                r'Traceback',
                r'RuntimeError',
                r'CUDA out of memory',
                r'OOM',
                r'OutOfMemoryError',
            ]
            
            # Look for warnings
            warning_patterns = [
                r'WARNING',
                r'WARN',
                r'NaN',
                r'nan',
                r'inf',
                r'Inf',
            ]
            
            for line in new_content.split('\n'):
                line_lower = line.lower()
                
                # Check for errors
                for pattern in error_patterns:
                    if re.search(pattern, line, re.IGNORECASE):
                        errors.append(line.strip())
                        break
                
                # Check for warnings
                for pattern in warning_patterns:
                    if re.search(pattern, line, re.IGNORECASE):
                        warnings.append(line.strip())
                        break
        
        return last_position, errors, warnings
    except Exception as e:
        return last_position, [f"Error reading log: {e}"], []


def extract_training_metrics(log_path: Path) -> Dict[str, any]:
    """Extract training metrics from log file."""
    metrics = {
        'epoch': None,
        'loss': None,
        'learning_rate': None,
        'step': None,
    }
    
    try:
        with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
            # Read last 1000 lines
            lines = f.readlines()[-1000:]
            
            for line in reversed(lines):
                # Look for epoch
                epoch_match = re.search(r'epoch[:\s]+(\d+)', line, re.IGNORECASE)
                if epoch_match and metrics['epoch'] is None:
                    metrics['epoch'] = int(epoch_match.group(1))
                
                # Look for loss
                loss_match = re.search(r'loss[:\s]+([\d.]+)', line, re.IGNORECASE)
                if loss_match and metrics['loss'] is None:
                    metrics['loss'] = float(loss_match.group(1))
                
                # Look for learning rate
                lr_match = re.search(r'lr[:\s]+([\d.e-]+)', line, re.IGNORECASE)
                if lr_match and metrics['learning_rate'] is None:
                    metrics['learning_rate'] = float(lr_match.group(1))
                
                # Look for step
                step_match = re.search(r'step[:\s]+(\d+)', line, re.IGNORECASE)
                if step_match and metrics['step'] is None:
                    metrics['step'] = int(step_match.group(1))
                
                # Stop if we found all metrics
                if all(v is not None for v in metrics.values()):
                    break
    except Exception:
        pass
    
    return metrics


def launch_tensorboard(tensorboard_dir: Path, port: int = 6006, background: bool = True) -> Optional[subprocess.Popen]:
    """Launch TensorBoard."""
    try:
        cmd = ['tensorboard', '--logdir', str(tensorboard_dir), '--port', str(port)]
        
        if background:
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                start_new_session=True
            )
            return process
        else:
            print(f"To launch TensorBoard manually, run:")
            print(f"  tensorboard --logdir {tensorboard_dir} --port {port}")
            return None
    except FileNotFoundError:
        print("WARNING: TensorBoard not found. Install with: pip install tensorboard")
        return None
    except Exception as e:
        print(f"WARNING: Failed to launch TensorBoard: {e}")
        return None


def monitor_training(
    experiment_dir: Path,
    log_path: Optional[Path] = None,
    check_interval: int = 30,
    launch_tb: bool = True,
    tensorboard_port: int = 6006
) -> None:
    """Monitor training progress."""
    print(f"Monitoring training in: {experiment_dir}")
    print(f"Check interval: {check_interval} seconds")
    print("Press Ctrl+C to stop monitoring\n")
    
    # Find log file if not specified
    if log_path is None:
        # Look for training log
        log_dir = experiment_dir / 'logs'
        if log_dir.exists():
            log_files = list(log_dir.glob('**/*.log'))
            if log_files:
                log_path = max(log_files, key=lambda p: p.stat().st_mtime)
                print(f"Found log file: {log_path}")
    
    # Check TensorBoard logs
    tensorboard_dir = check_tensorboard_logs(experiment_dir)
    tensorboard_process = None
    
    if tensorboard_dir and launch_tb:
        print(f"TensorBoard logs found: {tensorboard_dir}")
        tensorboard_process = launch_tensorboard(tensorboard_dir, tensorboard_port, background=True)
        if tensorboard_process:
            print(f"TensorBoard launched on port {tensorboard_port}")
            print(f"Access at: http://localhost:{tensorboard_port}")
        print()
    
    last_log_position = 0
    iteration = 0
    
    try:
        while True:
            iteration += 1
            print(f"\n{'='*80}")
            print(f"Status Check #{iteration} - {time.strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"{'='*80}")
            
            # Check GPU usage
            gpu_info = check_gpu_usage()
            if gpu_info['available']:
                print("\nGPU Status:")
                for gpu in gpu_info['gpus']:
                    mem_pct = (gpu['memory_used_mb'] / gpu['memory_total_mb']) * 100
                    print(f"  GPU {gpu['index']} ({gpu['name']}):")
                    print(f"    Utilization: {gpu['utilization']}%")
                    print(f"    Memory: {gpu['memory_used_mb']}/{gpu['memory_total_mb']} MB ({mem_pct:.1f}%)")
                    print(f"    Temperature: {gpu['temperature']}°C")
            else:
                print(f"\nGPU Status: {gpu_info.get('error', 'Not available')}")
            
            # Check training log
            if log_path and log_path.exists():
                # Extract metrics
                metrics = extract_training_metrics(log_path)
                if any(v is not None for v in metrics.values()):
                    print("\nTraining Metrics:")
                    for key, value in metrics.items():
                        if value is not None:
                            print(f"  {key}: {value}")
                
                # Check for errors/warnings
                last_log_position, errors, warnings = parse_training_log(log_path, last_log_position)
                
                if errors:
                    print(f"\n⚠ ERRORS DETECTED ({len(errors)}):")
                    for error in errors[-5:]:  # Show last 5 errors
                        print(f"  {error}")
                
                if warnings:
                    print(f"\n⚠ WARNINGS ({len(warnings)}):")
                    for warning in warnings[-5:]:  # Show last 5 warnings
                        print(f"  {warning}")
            
            # Check checkpoint directory
            checkpoint_dir = experiment_dir / 'checkpoints'
            if checkpoint_dir.exists():
                checkpoints = list(checkpoint_dir.glob('*.pth')) + list(checkpoint_dir.glob('*.pt'))
                if checkpoints:
                    latest = max(checkpoints, key=lambda p: p.stat().st_mtime)
                    size_mb = latest.stat().st_size / (1024 * 1024)
                    print(f"\nCheckpoints: {len(checkpoints)} found")
                    print(f"  Latest: {latest.name} ({size_mb:.1f} MB)")
            
            print(f"\nNext check in {check_interval} seconds... (Ctrl+C to stop)")
            time.sleep(check_interval)
    
    except KeyboardInterrupt:
        print("\n\nMonitoring stopped by user")
        if tensorboard_process:
            print("Stopping TensorBoard...")
            tensorboard_process.terminate()
            try:
                tensorboard_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                tensorboard_process.kill()


def main() -> int:
    """Main function."""
    parser = argparse.ArgumentParser(
        description='Monitor RF100-VL training progress'
    )
    parser.add_argument(
        '--experiment-dir',
        type=str,
        help='Path to experiment log directory (default: experiments/logs from .env.rf100vl or ./experiments/logs)'
    )
    parser.add_argument(
        '--log-path',
        type=str,
        help='Path to training log file (auto-detected if not specified)'
    )
    parser.add_argument(
        '--check-interval',
        type=int,
        default=30,
        help='Check interval in seconds (default: 30)'
    )
    parser.add_argument(
        '--no-tensorboard',
        action='store_true',
        help='Do not launch TensorBoard automatically'
    )
    parser.add_argument(
        '--tensorboard-port',
        type=int,
        default=6006,
        help='TensorBoard port (default: 6006)'
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
    
    log_path = project_root / args.log_path if args.log_path and not Path(args.log_path).is_absolute() else (Path(args.log_path) if args.log_path else None)
    
    if not experiment_dir.exists():
        print(f"WARNING: Experiment directory does not exist: {experiment_dir}", file=sys.stderr)
        print("This is normal if training hasn't started yet. Skipping monitoring.", file=sys.stderr)
        return 0  # Exit gracefully instead of erroring
    
    monitor_training(
        experiment_dir,
        log_path,
        args.check_interval,
        not args.no_tensorboard,
        args.tensorboard_port
    )
    
    return 0


if __name__ == '__main__':
    sys.exit(main())

