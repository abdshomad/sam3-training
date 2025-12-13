# SAM3 Training Repository

This repository is dedicated to training and fine-tuning the Meta Segment Anything Model 3 (SAM 3) with comprehensive automation scripts and orchestration tools.

## Overview

SAM 3 is a powerful segmentation model that can segment objects in images and videos based on text prompts, geometry, and image exemplars. This repository contains the SAM 3 codebase as a submodule and provides a dedicated workspace for training and fine-tuning tasks with automated setup, validation, and execution workflows.

## Repository Structure

- `sam3/` - SAM 3 codebase (git submodule from [facebookresearch/sam3](https://github.com/facebookresearch/sam3))
- `scripts/` - Training orchestration scripts and individual task scripts
- `plan/` - Implementation plan and task breakdown
- `experiments/` - Training logs, configs, and outputs
- `rf100-vl/` - Roboflow 100-VL dataset utilities

## Getting Started

### Prerequisites

- Python 3.8-3.12 (preferably 3.12)
- `uv` package manager ([installation guide](https://github.com/astral-sh/uv))
- CUDA-capable GPU (recommended for training)
- Git with submodule support

### Setup

1. Clone this repository:
   ```bash
   git clone --recurse-submodules <your-repo-url>
   ```

   Or if you've already cloned without submodules:
   ```bash
   git submodule update --init --recursive
   ```

2. Create virtual environment and install dependencies:
   ```bash
   uv venv
   source .venv/bin/activate  # or use: uv run
   uv sync
   ```

3. Install SAM3 training dependencies:
   ```bash
   cd sam3
   pip install -e ".[train]"
   cd ..
   ```

### Training

#### Quick Start with Orchestration Script

The recommended way to run training is using the master orchestration script:

```bash
bash scripts/run_training.sh \
    -c configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml \
    --mode local \
    --num-gpus 1
```

For detailed usage instructions, see [scripts/README_RUN_TRAINING.md](scripts/README_RUN_TRAINING.md).

#### Manual Training

For manual training without orchestration, refer to the [SAM 3 training documentation](sam3/README_TRAIN.md).

## Training Infrastructure

This repository includes a comprehensive training infrastructure organized into five main categories:

### 1. Environment Preparation
- Virtual environment setup and verification
- Python environment checks
- SAM3 dependency installation

### 2. Data Validation and Configuration
- Data root variable management
- Roboflow dataset download automation
- Data directory structure validation
- Configuration file existence checks

### 3. Script Argument Parsing
- Mode selection (local vs. cluster)
- Resource allocation flags (GPUs, nodes, partitions)
- Task type selection (train vs. eval)

### 4. Execution Logic Construction
- Local training command construction
- Cluster training command construction
- Job array configuration for dataset sweeps

### 5. Post-Execution and Monitoring
- Log directory feedback
- TensorBoard launch helper

All tasks have been implemented as individual scripts in the `scripts/` directory. For a detailed breakdown of all tasks, see [plan/plan.md](plan/plan.md).

## Individual Task Scripts

The `scripts/` directory contains modular scripts for each task:

- `task_10_environment_preparation.sh` - Environment setup
- `task_11_verify_python_environment.sh` - Python environment verification
- `task_12_install_sam3_dependencies.sh` - SAM3 dependency installation
- `task_20_data_validation_and_configuration.sh` - Data validation orchestration
- `task_21_define_data_root_variables.sh` - Data root variable setup
- `task_22_download_roboflow_dataset.sh` - Roboflow dataset download
- `task_24_validate_data_directory_structure.sh` - Directory structure validation (validates both rf100vl and ODinW datasets)
- `task_25_config_file_existence_check.sh` - Config file validation
- `task_30_script_argument_parsing.sh` - Argument parsing
- `task_31_implement_mode_selection.sh` - Mode selection logic
- `task_32_implement_resource_allocation_flags.sh` - Resource allocation
- `task_33_implement_task_type_selection.sh` - Task type selection
- `task_40_execution_logic_construction.sh` - Execution logic
- `task_41_construct_local_training_command.sh` - Local command construction
- `task_42_construct_cluster_training_command.sh` - Cluster command construction
- `task_43_job_array_configuration.sh` - Job array setup
- `task_50_post_execution_and_monitoring.sh` - Post-execution tasks
- `task_51_log_directory_feedback.sh` - Log directory extraction
- `task_52_tensorboard_launch_helper.sh` - TensorBoard helper

## Resources

- [SAM 3 Official Website](https://ai.meta.com/sam3/)
- [SAM 3 Paper](https://arxiv.org/abs/2511.16719)
- [Original SAM 3 Repository](https://github.com/facebookresearch/sam3)
- [Training Documentation](scripts/README_RUN_TRAINING.md)
- [Implementation Plan](plan/plan.md)

## License

This repository follows the SAM License. See the [LICENSE](sam3/LICENSE) file in the submodule for details.