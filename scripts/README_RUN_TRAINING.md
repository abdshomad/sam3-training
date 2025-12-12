# SAM3 Training Orchestration Script

The `run_training.sh` script is a master orchestration script that automates the entire SAM3 training workflow, from environment setup to post-execution monitoring.

## Overview

This script orchestrates all training setup and execution steps in the correct sequence:

1. **Environment Setup** - Creates virtual environment and installs dependencies
2. **Data Validation** - Validates/downloads datasets (Roboflow/ODinW)
3. **Config Validation** - Verifies training config file exists
4. **Argument Parsing** - Parses and validates training arguments
5. **Training Execution** - Constructs and executes the training command
6. **Post-Execution Monitoring** - Extracts log directory and provides TensorBoard guidance

## Prerequisites

- Python 3.8-3.12 (preferably 3.12)
- `uv` package manager installed
- CUDA-capable GPU (recommended)
- Access to SAM3 codebase (submodule)

## Quick Start

### Basic Local Training

```bash
bash scripts/run_training.sh \
    -c configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml \
    --mode local \
    --num-gpus 1
```

### Basic Cluster Training

```bash
bash scripts/run_training.sh \
    -c configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml \
    --mode cluster \
    --num-gpus 8 \
    --num-nodes 2 \
    --partition gpu_partition \
    --account my_account
```

## Command-Line Options

### Required Options

- **`-c, --config PATH`** - Training configuration file path (required)
  - Examples:
    - `configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml`
    - `roboflow_v100/roboflow_v100_full_ft_100_images.yaml`
    - `odinw13/odinw_text_only_train.yaml`

### Execution Options

- **`--mode MODE`** - Execution mode: `local` or `cluster` (default: `local`)
  - `local`: Run training on local machine
  - `cluster`: Run training on SLURM cluster

- **`--num-gpus N`** - Number of GPUs per node (positive integer)

- **`--num-nodes N`** - Number of nodes for distributed training (positive integer)

### Cluster Options (for `--mode cluster`)

- **`--partition NAME`** - SLURM partition name

- **`--account NAME`** - SLURM account name

- **`--qos NAME`** - SLURM QOS (Quality of Service) setting

### Data Options

- **`--roboflow-root PATH`** - Path to Roboflow VL-100 dataset root directory

- **`--odinw-root PATH`** - Path to ODinW dataset root directory

- **`--dataset-type TYPE`** - Dataset type to validate: `roboflow`, `odinw`, or `both` (default: `both`)

### Control Options

- **`--skip-env-setup`** - Skip environment setup step (use if venv already exists)

- **`--skip-data-validation`** - Skip data validation step

- **`--skip-config-validation`** - Skip config file validation step

- **`--output-log PATH`** - Path to save training output log (default: auto-generated in `experiments/logs/`)

- **`--dry-run`** - Construct command but don't execute training (useful for testing)

- **`-h, --help`** - Show help message

## Usage Examples

### Example 1: Local Training with Single GPU

```bash
bash scripts/run_training.sh \
    -c configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml \
    --mode local \
    --num-gpus 1
```

### Example 2: Local Multi-GPU Training

```bash
bash scripts/run_training.sh \
    -c configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml \
    --mode local \
    --num-gpus 4
```

### Example 3: Cluster Training with SLURM

```bash
bash scripts/run_training.sh \
    -c configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml \
    --mode cluster \
    --num-gpus 8 \
    --num-nodes 2 \
    --partition gpu_partition \
    --account my_account \
    --qos high_priority
```

### Example 4: With Data Validation

```bash
bash scripts/run_training.sh \
    -c configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml \
    --mode local \
    --num-gpus 1 \
    --roboflow-root /path/to/roboflow/datasets \
    --odinw-root /path/to/odinw/datasets \
    --dataset-type both
```

### Example 5: Skip Optional Steps (Faster Re-runs)

```bash
bash scripts/run_training.sh \
    -c configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml \
    --mode local \
    --num-gpus 1 \
    --skip-env-setup \
    --skip-data-validation
```

### Example 6: Dry Run (Test Configuration)

```bash
bash scripts/run_training.sh \
    -c configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml \
    --mode local \
    --num-gpus 1 \
    --dry-run
```

### Example 7: Custom Output Log Location

```bash
bash scripts/run_training.sh \
    -c configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml \
    --mode local \
    --num-gpus 1 \
    --output-log /path/to/custom/training.log
```

### Example 8: ODinW Training

```bash
bash scripts/run_training.sh \
    -c configs/odinw13/odinw_text_only_train.yaml \
    --mode local \
    --num-gpus 2 \
    --odinw-root /path/to/odinw/datasets
```

## Step-by-Step Workflow

The script executes the following steps automatically:

### Step 1: Environment Setup
- Creates/activates Python virtual environment using `uv`
- Verifies Python version (3.8-3.12)
- Installs SAM3 dependencies (`pip install -e ".[train]"` in `sam3/` directory)

**Skip with:** `--skip-env-setup`

### Step 2: Data Validation
- Defines data root variables (`roboflow_vl_100_root`, `odinw_data_root`)
- Downloads Roboflow dataset if needed (requires `ROBOFLOW_API_KEY` environment variable)
- Validates data directory structure

**Skip with:** `--skip-data-validation`

### Step 3: Config Validation
- Verifies that the specified config file exists in `sam3/sam3/train/configs/`
- Normalizes config path if needed
- Lists available configs if validation fails

**Skip with:** `--skip-config-validation`

### Step 4: Argument Parsing
- Parses and validates all training arguments
- Maps `--mode local/cluster` to `--use-cluster 0/1`
- Validates resource allocation parameters
- Exports variables for downstream scripts

### Step 5: Training Execution
- Constructs the training command: `python -m sam3.train.train -c <config> [options]`
- Executes the training command
- Captures output to log file (default: `experiments/logs/training_<config>_<timestamp>.log`)

**Test without executing:** `--dry-run`

### Step 6: Post-Execution Monitoring
- Extracts experiment log directory from config or training output
- Provides TensorBoard launch command
- Displays key locations (checkpoints, configs, logs)

## Output and Logging

### Training Output Log

By default, training output is saved to:
```
experiments/logs/training_<config_name>_<timestamp>.log
```

You can specify a custom location with `--output-log PATH`.

The log contains:
- All training output (stdout and stderr)
- Training progress
- Error messages
- Experiment log directory location

### Experiment Log Directory

After training starts, the experiment log directory is created at:
```
<experiment_log_dir>/  (as specified in config or default location)
├── config.yaml              # Original config
├── config_resolved.yaml     # Resolved config with all values
├── checkpoints/             # Model checkpoints
├── tensorboard/             # TensorBoard logs
├── logs/                    # Text logs
└── submitit_logs/           # SLURM logs (cluster mode only)
```

## Monitoring Training

### TensorBoard

After training starts, the script will suggest a TensorBoard command:

```bash
tensorboard --logdir <experiment_log_dir>/tensorboard
```

Launch TensorBoard in a separate terminal to monitor training progress.

### For Local Training

- Training runs in the foreground
- Check terminal output for real-time progress
- Use `Ctrl+C` to stop (may cause checkpoint corruption)

### For Cluster Training

- Job is submitted to SLURM queue
- Monitor job status: `squeue -u $USER`
- View job output: Check SLURM output files in `submitit_logs/`
- Cancel job: `scancel <job_id>`

## Troubleshooting

### Environment Setup Fails

**Problem:** Virtual environment creation fails

**Solutions:**
- Ensure `uv` is installed: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- Check Python version: `python --version` (should be 3.8-3.12)
- Try skipping: `--skip-env-setup` (if venv already exists)

### Data Validation Fails

**Problem:** Dataset validation fails or datasets not found

**Solutions:**
- Provide dataset paths: `--roboflow-root <path>` and/or `--odinw-root <path>`
- Set `ROBOFLOW_API_KEY` environment variable for downloads
- Skip data validation: `--skip-data-validation` (if datasets already validated)
- Check dataset directory structure matches expected format

### Config File Not Found

**Problem:** Config file validation fails

**Solutions:**
- List available configs: `bash scripts/task_24_config_file_existence_check.sh`
- Use correct path format: `configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml`
- Check config exists in: `sam3/sam3/train/configs/`

### Training Command Fails

**Problem:** Training execution fails

**Solutions:**
- Check training output log for error messages
- Verify GPU availability: `nvidia-smi`
- Check CUDA installation and compatibility
- Review resolved config: `<experiment_log_dir>/config_resolved.yaml`
- Ensure datasets are accessible and properly formatted

### Cluster Job Not Starting

**Problem:** SLURM job doesn't start

**Solutions:**
- Check job status: `squeue -u $USER`
- Verify partition, account, and QOS settings
- Check SLURM output files for errors
- Ensure cluster resources are available

## Environment Variables

The script uses and exports several environment variables:

- `SAM3_CONFIG_ARG` - Config file path
- `SAM3_USE_CLUSTER` - Cluster mode (0 or 1)
- `SAM3_NUM_GPUS` - Number of GPUs
- `SAM3_NUM_NODES` - Number of nodes
- `SAM3_PARTITION` - SLURM partition
- `SAM3_ACCOUNT` - SLURM account
- `SAM3_QOS` - SLURM QOS
- `SAM3_TRAIN_COMMAND` - Constructed training command
- `SAM3_EXPERIMENT_LOG_DIR` - Experiment log directory
- `SAM3_TRAINING_OUTPUT_LOG` - Training output log path

## Related Scripts

The master script orchestrates these individual task scripts:

- `task_10_environment_preparation.sh` - Environment setup
- `task_20_data_validation_and_configuration.sh` - Data validation
- `task_24_config_file_existence_check.sh` - Config validation
- `task_30_script_argument_parsing.sh` - Argument parsing
- `task_40_execution_logic_construction.sh` - Command construction
- `task_50_post_execution_and_monitoring.sh` - Post-execution monitoring

You can run these scripts individually if needed, but the master script is recommended for full workflow automation.

## Getting Help

For detailed help on the script:

```bash
bash scripts/run_training.sh --help
```

For help on individual task scripts:

```bash
bash scripts/task_<ID>_<name>.sh --help
```

## Additional Resources

- [SAM3 Training Documentation](sam3/README_TRAIN.md)
- [SAM3 Official Repository](https://github.com/facebookresearch/sam3)
- [Project Plan](plan/plan.md)

