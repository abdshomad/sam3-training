#!/bin/bash
# Task ID: 7.1
# Description: Training Launch Script for RF100-VL
# Created: 2025-12-13
#
# This script launches rf100-vl training using the run_training.sh infrastructure
# with automatic config resolution and validation.

set -e

# Get the script directory and project root
# Script is now in root, so SCRIPT_DIR = PROJECT_ROOT
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"

# Change to project root
cd "${PROJECT_ROOT}"

# Load environment variables from .env file if it exists
if [ -f "${PROJECT_ROOT}/.env" ]; then
    set -a  # Automatically export all variables
    source "${PROJECT_ROOT}/.env"
    set +a  # Turn off automatic export
fi

# Load RF100-VL specific environment variables from .env.rf100vl if it exists
# This file contains RF100-VL specific settings and overrides
if [ -f "${PROJECT_ROOT}/.env.rf100vl" ]; then
    set -a  # Automatically export all variables
    source "${PROJECT_ROOT}/.env.rf100vl"
    set +a  # Turn off automatic export
fi

# Default values (can be overridden by .env.rf100vl or CLI args)
BASE_CONFIG="sam3/sam3/train/configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml"
SUPERCATEGORY="${RF100VL_DEFAULT_SUPERCATEGORY:-all}"  # Default to all supercategories (job array)
MODE="${RF100VL_DEFAULT_MODE:-local}"
NUM_GPUS="${RF100VL_DEFAULT_NUM_GPUS:-}"
NUM_NODES=""
PARTITION=""
ACCOUNT=""
QOS=""
ROBOFLOW_ROOT="${ROBOFLOW_VL_100_ROOT:-}"
EXPERIMENT_DIR="${EXPERIMENT_LOG_DIR:-}"
BPE_PATH="${BPE_PATH:-}"
SKIP_CONFIG_RESOLUTION=false
SKIP_CONFIG_VALIDATION=false
SKIP_ENV_SETUP=false
SKIP_DATA_VALIDATION=false
DRY_RUN=false
USE_RESOLVED_CONFIG=true

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --supercategory)
            SUPERCATEGORY="$2"
            shift 2
            ;;
        --mode)
            MODE="$2"
            shift 2
            ;;
        --num-gpus)
            NUM_GPUS="$2"
            shift 2
            ;;
        --num-nodes)
            NUM_NODES="$2"
            shift 2
            ;;
        --partition)
            PARTITION="$2"
            shift 2
            ;;
        --account)
            ACCOUNT="$2"
            shift 2
            ;;
        --qos)
            QOS="$2"
            shift 2
            ;;
        --roboflow-root)
            ROBOFLOW_ROOT="$2"
            shift 2
            ;;
        --experiment-dir)
            EXPERIMENT_DIR="$2"
            shift 2
            ;;
        --bpe-path)
            BPE_PATH="$2"
            shift 2
            ;;
        --base-config)
            BASE_CONFIG="$2"
            shift 2
            ;;
        --skip-config-resolution)
            SKIP_CONFIG_RESOLUTION=true
            shift
            ;;
        --skip-config-validation)
            SKIP_CONFIG_VALIDATION=true
            shift
            ;;
        --skip-env-setup)
            SKIP_ENV_SETUP=true
            shift
            ;;
        --skip-data-validation)
            SKIP_DATA_VALIDATION=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            cat << EOF
Usage: $0 [OPTIONS]

Launch RF100-VL training with automatic config resolution and validation.

Options:
  --supercategory NAME     Supercategory to train on (default: 'all' for job array)

Execution Options:
  --mode MODE              Execution mode: local or cluster (default: local)
  --num-gpus N             Number of GPUs per node
  --num-nodes N            Number of nodes for distributed training
  --partition NAME         SLURM partition name (cluster mode)
  --account NAME           SLURM account name (cluster mode)
  --qos NAME               SLURM QOS setting (cluster mode)

Path Options:
  --roboflow-root PATH     Path to Roboflow VL-100 dataset root
  --experiment-dir PATH    Path to experiment log directory
  --bpe-path PATH          Path to BPE vocabulary file
  --base-config PATH       Base config file (default: roboflow_v100_full_ft_100_images.yaml)

Control Options:
  --skip-config-resolution Skip config path resolution step
  --skip-config-validation Skip config validation step
  --skip-env-setup         Skip environment setup step
  --skip-data-validation   Skip data validation step
  --dry-run                Show what would be done without executing
  --help, -h               Show this help message

Environment Variables:
  ROBOFLOW_VL_100_ROOT     Path to Roboflow dataset root
  EXPERIMENT_LOG_DIR        Path to experiment log directory
  BPE_PATH                  Path to BPE vocabulary file

Examples:
  # Local training on all supercategories (default)
  $0 --mode local --num-gpus 1

  # Local training on single supercategory
  $0 --supercategory actions --mode local --num-gpus 1

  # Local training with custom paths (all supercategories by default)
  $0 --mode local --num-gpus 1 \\
     --roboflow-root ./data/roboflow_vl_100 \\
     --experiment-dir ./experiments/logs

  # Cluster training (all supercategories by default)
  $0 --mode cluster --num-gpus 8 --num-nodes 2 \\
     --partition gpu_partition --account my_account

  # Dry run to see what would happen
  $0 --mode local --num-gpus 1 --dry-run
EOF
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Supercategory defaults to "all" if not specified
# No validation needed - default is already set above

echo "=========================================="
echo "RF100-VL Training Launch Script"
echo "=========================================="
echo ""

# ============================================================================
# Step 1: Config Path Resolution
# ============================================================================
RESOLVED_CONFIG=""
if [ "${SKIP_CONFIG_RESOLUTION}" = false ]; then
    echo "Step 1: Resolving config paths..."
    echo "----------------------------------------"
    
    RESOLVED_CONFIG_DIR="${PROJECT_ROOT}/experiments/configs"
    mkdir -p "${RESOLVED_CONFIG_DIR}"
    
    # Generate resolved config filename
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    RESOLVED_CONFIG="${RESOLVED_CONFIG_DIR}/resolved_config_${SUPERCATEGORY}_${TIMESTAMP}.yaml"
    
    # Build config resolution command
    RESOLVE_ARGS=(
        --base-config "${BASE_CONFIG}"
        --output "${RESOLVED_CONFIG}"
    )
    
    if [ -n "${ROBOFLOW_ROOT}" ]; then
        RESOLVE_ARGS+=(--roboflow-root "${ROBOFLOW_ROOT}")
    fi
    
    if [ -n "${EXPERIMENT_DIR}" ]; then
        RESOLVE_ARGS+=(--experiment-dir "${EXPERIMENT_DIR}")
    fi
    
    if [ -n "${BPE_PATH}" ]; then
        RESOLVE_ARGS+=(--bpe-path "${BPE_PATH}")
    fi
    
    if [ "${DRY_RUN}" = true ]; then
        RESOLVE_ARGS+=(--dry-run)
    fi
    
    # Run config resolution
    if [ "${DRY_RUN}" = true ]; then
        echo "Would run: uv run python scripts/task_61_config_path_resolution.py ${RESOLVE_ARGS[*]}"
    else
        uv run python scripts/task_61_config_path_resolution.py "${RESOLVE_ARGS[@]}"
        if [ $? -ne 0 ]; then
            echo "ERROR: Config path resolution failed" >&2
            exit 1
        fi
        echo "✓ Config resolved: ${RESOLVED_CONFIG}"
    fi
    echo ""
else
    echo "Skipping Step 1: Config Path Resolution (--skip-config-resolution)"
    echo ""
    # Use base config if resolution is skipped
    RESOLVED_CONFIG="${BASE_CONFIG}"
fi

# ============================================================================
# Step 2: Supercategory Selection/Override
# ============================================================================
if [ "${SKIP_CONFIG_RESOLUTION}" = false ] && [ "${DRY_RUN}" = false ]; then
    echo "Step 2: Setting supercategory..."
    echo "----------------------------------------"
    
    # If supercategory is not 'all', we need to override it in the config
    if [ "${SUPERCATEGORY}" != "all" ]; then
        # Use Python to update the config
        uv run python -c "
import yaml
import sys

config_path = '${RESOLVED_CONFIG}'
supercategory = '${SUPERCATEGORY}'

with open(config_path, 'r') as f:
    config = yaml.safe_load(f)

# Update supercategory
if 'roboflow_train' not in config:
    config['roboflow_train'] = {}
config['roboflow_train']['supercategory'] = supercategory

with open(config_path, 'w') as f:
    yaml.dump(config, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

print(f'✓ Set supercategory to: {supercategory}')
"
        echo ""
    else
        echo "✓ Using job array for all supercategories"
        echo ""
    fi
fi

# ============================================================================
# Step 3: Config Validation
# ============================================================================
if [ "${SKIP_CONFIG_VALIDATION}" = false ] && [ "${DRY_RUN}" = false ]; then
    echo "Step 3: Validating config..."
    echo "----------------------------------------"
    
    VALIDATE_ARGS=(--config "${RESOLVED_CONFIG}")
    
    if [ "${MODE}" = "cluster" ]; then
        VALIDATE_ARGS+=(--skip-gpu-check)
    fi
    
    if [ "${DRY_RUN}" = true ]; then
        echo "Would run: uv run python scripts/task_62_config_validation.py ${VALIDATE_ARGS[*]}"
    else
        uv run python scripts/task_62_config_validation.py "${VALIDATE_ARGS[@]}"
        if [ $? -ne 0 ]; then
            echo "ERROR: Config validation failed" >&2
            exit 1
        fi
    fi
    echo ""
else
    echo "Skipping Step 3: Config Validation (--skip-config-validation)"
    echo ""
fi

# ============================================================================
# Step 4: Launch Training
# ============================================================================
echo "Step 4: Launching training..."
echo "----------------------------------------"

# Build run_training.sh command
TRAINING_ARGS=(
    -c "${RESOLVED_CONFIG}"
    --mode "${MODE}"
)

if [ -n "${NUM_GPUS}" ]; then
    TRAINING_ARGS+=(--num-gpus "${NUM_GPUS}")
fi

if [ -n "${NUM_NODES}" ]; then
    TRAINING_ARGS+=(--num-nodes "${NUM_NODES}")
fi

if [ -n "${PARTITION}" ]; then
    TRAINING_ARGS+=(--partition "${PARTITION}")
fi

if [ -n "${ACCOUNT}" ]; then
    TRAINING_ARGS+=(--account "${ACCOUNT}")
fi

if [ -n "${QOS}" ]; then
    TRAINING_ARGS+=(--qos "${QOS}")
fi

if [ -n "${ROBOFLOW_ROOT}" ]; then
    TRAINING_ARGS+=(--roboflow-root "${ROBOFLOW_ROOT}")
fi

if [ "${SKIP_ENV_SETUP}" = true ]; then
    TRAINING_ARGS+=(--skip-env-setup)
fi

if [ "${SKIP_DATA_VALIDATION}" = true ]; then
    TRAINING_ARGS+=(--skip-data-validation)
fi

if [ "${DRY_RUN}" = true ]; then
    TRAINING_ARGS+=(--dry-run)
fi

if [ "${DRY_RUN}" = true ]; then
    echo "Would run: bash ./run_training.sh ${TRAINING_ARGS[*]}"
    echo ""
    echo "Dry run complete. Remove --dry-run to execute training."
    exit 0
else
    echo "Executing: bash ./run_training.sh ${TRAINING_ARGS[*]}"
    echo ""
    bash ./run_training.sh "${TRAINING_ARGS[@]}"
    TRAINING_EXIT_CODE=$?
    
    if [ ${TRAINING_EXIT_CODE} -eq 0 ]; then
        echo ""
        echo "=========================================="
        echo "Training launched successfully!"
        echo "=========================================="
        echo ""
        echo "Resolved config: ${RESOLVED_CONFIG}"
        echo "Monitor training progress using TensorBoard or check logs."
    else
        echo ""
        echo "ERROR: Training launch failed (exit code: ${TRAINING_EXIT_CODE})" >&2
        exit ${TRAINING_EXIT_CODE}
    fi
fi

