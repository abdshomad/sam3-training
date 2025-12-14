#!/bin/bash
# Task ID: 7.3
# Description: Training Launch Script for Chicken Detection Dataset
# Created: 2025-12-15
#
# This script launches chicken detection training using the run_training.sh infrastructure
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

# Load Chicken Detection specific environment variables from .env.chicken if it exists
# This file contains Chicken Detection specific settings and overrides
if [ -f "${PROJECT_ROOT}/.env.chicken" ]; then
    set -a  # Automatically export all variables
    source "${PROJECT_ROOT}/.env.chicken"
    set +a  # Turn off automatic export
fi

# Default values (can be overridden by .env.chicken or CLI args)
BASE_CONFIG="sam3/sam3/train/configs/chicken_detection/chicken_detection_train.yaml"
MODE="${CHICKEN_DEFAULT_MODE:-local}"
NUM_GPUS="${CHICKEN_DEFAULT_NUM_GPUS:-}"
NUM_NODES=""
PARTITION=""
ACCOUNT=""
QOS=""
CHICKEN_ROOT="${CHICKEN_DATA_ROOT:-}"
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
        --chicken-root)
            CHICKEN_ROOT="$2"
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

Launch Chicken Detection training with automatic config resolution and validation.

Execution Options:
  --mode MODE              Execution mode: local or cluster (default: local)
  --num-gpus N             Number of GPUs per node
  --num-nodes N            Number of nodes for distributed training
  --partition NAME         SLURM partition name (cluster mode)
  --account NAME           SLURM account name (cluster mode)
  --qos NAME               SLURM QOS setting (cluster mode)

Path Options:
  --chicken-root PATH      Path to Chicken Detection dataset root (data/chicken-and-not-chicken/)
  --experiment-dir PATH    Path to experiment log directory
  --bpe-path PATH          Path to BPE vocabulary file
  --base-config PATH       Base config file (default: chicken_detection_train.yaml)

Control Options:
  --skip-config-resolution Skip config path resolution step
  --skip-config-validation Skip config validation step
  --skip-env-setup         Skip environment setup step
  --skip-data-validation   Skip data validation step
  --dry-run                Show what would be done without executing
  --help, -h               Show this help message

Environment Variables:
  CHICKEN_DATA_ROOT        Path to Chicken Detection dataset root
  EXPERIMENT_LOG_DIR        Path to experiment log directory
  BPE_PATH                  Path to BPE vocabulary file

Examples:
  # Local training
  $0 --mode local --num-gpus 1

  # Local training with custom paths
  $0 --mode local --num-gpus 1 \\
     --chicken-root ./data/chicken-and-not-chicken \\
     --experiment-dir ./experiments/logs

  # Cluster training
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

echo "=========================================="
echo "Chicken Detection Training Launch Script"
echo "=========================================="
echo ""

# ============================================================================
# Pre-flight: Check and fix .venv permissions and environment
# ============================================================================
# Unset VIRTUAL_ENV if it points to a different location (e.g., from Docker)
if [ -n "${VIRTUAL_ENV}" ] && [ "${VIRTUAL_ENV}" != "${PROJECT_ROOT}/.venv" ]; then
    echo "WARNING: VIRTUAL_ENV is set to '${VIRTUAL_ENV}' but project uses '${PROJECT_ROOT}/.venv'"
    echo "Unsetting VIRTUAL_ENV to avoid conflicts..."
    unset VIRTUAL_ENV
    echo ""
fi

# Check .venv ownership if it exists
if [ -d "${PROJECT_ROOT}/.venv" ]; then
    VENV_OWNER=$(stat -c '%U' "${PROJECT_ROOT}/.venv" 2>/dev/null || stat -f '%Su' "${PROJECT_ROOT}/.venv" 2>/dev/null || echo "unknown")
    CURRENT_USER=$(whoami)
    
    if [ "${VENV_OWNER}" != "${CURRENT_USER}" ] && [ "${VENV_OWNER}" != "unknown" ]; then
        echo "WARNING: .venv directory is owned by '${VENV_OWNER}' but current user is '${CURRENT_USER}'"
        echo "This will cause permission errors with uv. Attempting to fix ownership..."
        echo ""
        
        # Try to fix ownership (requires sudo, but preserves the venv)
        if sudo chown -R "${CURRENT_USER}:${CURRENT_USER}" "${PROJECT_ROOT}/.venv" 2>/dev/null; then
            echo "✓ Fixed .venv ownership"
        else
            echo "ERROR: Cannot fix .venv ownership (sudo required)"
            echo ""
            echo "Please run the following command to fix this:"
            echo "  sudo chown -R ${CURRENT_USER}:${CURRENT_USER} ${PROJECT_ROOT}/.venv"
            echo ""
            echo "Alternatively, if you want to recreate the venv:"
            echo "  sudo rm -rf ${PROJECT_ROOT}/.venv"
            echo ""
            exit 1
        fi
        echo ""
    fi
fi

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
    RESOLVED_CONFIG="${RESOLVED_CONFIG_DIR}/chicken_resolved_config_${TIMESTAMP}.yaml"
    
    # Build config resolution command
    RESOLVE_ARGS=(
        --base-config "${BASE_CONFIG}"
        --output "${RESOLVED_CONFIG}"
    )
    
    if [ -n "${CHICKEN_ROOT}" ]; then
        RESOLVE_ARGS+=(--chicken-root "${CHICKEN_ROOT}")
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
    # Note: We'll need to create a config resolution script for chicken dataset
    # For now, we'll use a simple Python script or skip if not available
    if [ -f "${PROJECT_ROOT}/scripts/task_chicken_config_path_resolution.py" ]; then
        if [ "${DRY_RUN}" = true ]; then
            echo "Would run: uv run python scripts/task_chicken_config_path_resolution.py ${RESOLVE_ARGS[*]}"
        else
            uv run python scripts/task_chicken_config_path_resolution.py "${RESOLVE_ARGS[@]}"
            if [ $? -ne 0 ]; then
                echo "ERROR: Config path resolution failed" >&2
                exit 1
            fi
            echo "✓ Config resolved: ${RESOLVED_CONFIG}"
        fi
    else
        echo "NOTE: Config resolution script not found. Using base config directly."
        echo "      Create scripts/task_chicken_config_path_resolution.py for automatic path resolution."
        RESOLVED_CONFIG="${BASE_CONFIG}"
    fi
    echo ""
else
    echo "Skipping Step 1: Config Path Resolution (--skip-config-resolution)"
    echo ""
    # Use base config if resolution is skipped
    RESOLVED_CONFIG="${BASE_CONFIG}"
fi

# ============================================================================
# Step 2: Config Validation
# ============================================================================
if [ "${SKIP_CONFIG_VALIDATION}" = false ] && [ "${DRY_RUN}" = false ]; then
    echo "Step 2: Validating config..."
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
    echo "Skipping Step 2: Config Validation (--skip-config-validation)"
    echo ""
fi

# ============================================================================
# Step 3: Launch Training
# ============================================================================
echo "Step 3: Launching training..."
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

if [ -n "${CHICKEN_ROOT}" ]; then
    TRAINING_ARGS+=(--chicken-root "${CHICKEN_ROOT}")
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
    echo "Executing: bash ./run_training.sh ${TRAINING_ARGS[@]}"
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
