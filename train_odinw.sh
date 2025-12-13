#!/bin/bash
# Task ID: 7.2
# Description: Training Launch Script for ODinW
# Created: 2025-12-13
#
# This script launches ODinW training using the run_training.sh infrastructure
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

# Load ODinW specific environment variables from .env.odinw if it exists
# This file contains ODinW specific settings and overrides
if [ -f "${PROJECT_ROOT}/.env.odinw" ]; then
    set -a  # Automatically export all variables
    source "${PROJECT_ROOT}/.env.odinw"
    set +a  # Turn off automatic export
fi

# Default values (can be overridden by .env.odinw or CLI args)
CONFIG_TYPE="${ODINW_DEFAULT_CONFIG_TYPE:-text_only}"  # text_only, text_and_visual, visual_only, text_only_positive
MODE="${ODINW_DEFAULT_MODE:-local}"
NUM_GPUS="${ODINW_DEFAULT_NUM_GPUS:-}"
NUM_NODES=""
PARTITION=""
ACCOUNT=""
QOS=""
ODINW_ROOT="${ODINW_DATA_ROOT:-}"
EXPERIMENT_DIR="${EXPERIMENT_LOG_DIR:-}"
BPE_PATH="${BPE_PATH:-}"
SKIP_CONFIG_RESOLUTION=false
SKIP_CONFIG_VALIDATION=false
SKIP_ENV_SETUP=false
SKIP_DATA_VALIDATION=false
DRY_RUN=false
USE_RESOLVED_CONFIG=true
AUTO_DOWNLOAD=false

# Map config type to base config file
case "${CONFIG_TYPE}" in
    text_only)
        BASE_CONFIG="sam3/sam3/train/configs/odinw13/odinw_text_only_train.yaml"
        ;;
    text_and_visual)
        BASE_CONFIG="sam3/sam3/train/configs/odinw13/odinw_text_and_visual.yaml"
        ;;
    visual_only)
        BASE_CONFIG="sam3/sam3/train/configs/odinw13/odinw_visual_only.yaml"
        ;;
    text_only_positive)
        BASE_CONFIG="sam3/sam3/train/configs/odinw13/odinw_text_only_positive.yaml"
        ;;
    *)
        echo "ERROR: Unknown config type: ${CONFIG_TYPE}" >&2
        echo "Valid types: text_only, text_and_visual, visual_only, text_only_positive" >&2
        exit 1
        ;;
esac

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --config-type)
            CONFIG_TYPE="$2"
            # Update BASE_CONFIG based on new config type
            case "${CONFIG_TYPE}" in
                text_only)
                    BASE_CONFIG="sam3/sam3/train/configs/odinw13/odinw_text_only_train.yaml"
                    ;;
                text_and_visual)
                    BASE_CONFIG="sam3/sam3/train/configs/odinw13/odinw_text_and_visual.yaml"
                    ;;
                visual_only)
                    BASE_CONFIG="sam3/sam3/train/configs/odinw13/odinw_visual_only.yaml"
                    ;;
                text_only_positive)
                    BASE_CONFIG="sam3/sam3/train/configs/odinw13/odinw_text_only_positive.yaml"
                    ;;
                *)
                    echo "ERROR: Unknown config type: ${CONFIG_TYPE}" >&2
                    exit 1
                    ;;
            esac
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
        --odinw-root)
            ODINW_ROOT="$2"
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
        --auto-download)
            AUTO_DOWNLOAD=true
            shift
            ;;
        --help|-h)
            cat << EOF
Usage: $0 [OPTIONS]

Launch ODinW training with automatic config resolution and validation.

Options:
  --config-type TYPE        Config type: text_only (default), text_and_visual, 
                            visual_only, text_only_positive

Execution Options:
  --mode MODE               Execution mode: local or cluster (default: local)
  --num-gpus N              Number of GPUs per node
  --num-nodes N             Number of nodes for distributed training
  --partition NAME          SLURM partition name (cluster mode)
  --account NAME            SLURM account name (cluster mode)
  --qos NAME                SLURM QOS setting (cluster mode)

Path Options:
  --odinw-root PATH         Path to ODinW dataset root
  --experiment-dir PATH     Path to experiment log directory
  --bpe-path PATH           Path to BPE vocabulary file
  --base-config PATH        Base config file (overrides --config-type)

Control Options:
  --skip-config-resolution  Skip config path resolution step
  --skip-config-validation  Skip config validation step
  --skip-env-setup          Skip environment setup step
  --skip-data-validation    Skip data validation step
  --auto-download           Automatically download missing datasets when validation fails
  --dry-run                 Show what would be done without executing
  --help, -h                Show this help message

Environment Variables:
  ODINW_DATA_ROOT           Path to ODinW dataset root
  EXPERIMENT_LOG_DIR        Path to experiment log directory
  BPE_PATH                  Path to BPE vocabulary file
  ODINW_DEFAULT_CONFIG_TYPE Default config type (text_only, text_and_visual, etc.)
  ODINW_DEFAULT_MODE        Default execution mode (local or cluster)
  ODINW_DEFAULT_NUM_GPUS    Default number of GPUs

Examples:
  # Local training with default text_only config
  $0 --mode local --num-gpus 1

  # Local training with text_and_visual config
  $0 --config-type text_and_visual --mode local --num-gpus 1

  # Local training with custom paths
  $0 --mode local --num-gpus 1 \\
     --odinw-root ./data/odinw \\
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
echo "ODinW Training Launch Script"
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
    RESOLVED_CONFIG="${RESOLVED_CONFIG_DIR}/odinw_resolved_config_${CONFIG_TYPE}_${TIMESTAMP}.yaml"
    
    # Build config resolution command
    RESOLVE_ARGS=(
        --base-config "${BASE_CONFIG}"
        --output "${RESOLVED_CONFIG}"
    )
    
    if [ -n "${ODINW_ROOT}" ]; then
        RESOLVE_ARGS+=(--odinw-root "${ODINW_ROOT}")
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
        echo "Would run: bash scripts/task_64_odinw_config_path_resolution.sh ${RESOLVE_ARGS[*]}"
    else
        bash scripts/task_64_odinw_config_path_resolution.sh "${RESOLVE_ARGS[@]}"
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
        VALIDATION_EXIT_CODE=$?
        if [ ${VALIDATION_EXIT_CODE} -ne 0 ]; then
            echo ""
            echo "=========================================="
            echo "ERROR: Config validation failed"
            echo "=========================================="
            echo ""
            
            # Check if download script exists
            if [ -f "${PROJECT_ROOT}/scripts/task_23_download_odinw_dataset.sh" ]; then
                echo "ODinW dataset appears to be missing or incomplete."
                echo ""
                
                # Auto-download if flag is set
                if [ "${AUTO_DOWNLOAD}" = true ]; then
                    echo "Auto-download enabled. Downloading missing ODinW datasets..."
                    echo "----------------------------------------"
                    # Use --missing-only to only download what's needed
                    DOWNLOAD_ARGS=("--missing-only" "--config" "${RESOLVED_CONFIG}")
                    if [ -n "${ODINW_ROOT:-${ODINW_DATA_ROOT:-}}" ]; then
                        DOWNLOAD_ARGS+=("${ODINW_ROOT:-${ODINW_DATA_ROOT:-}}")
                    fi
                    bash "${PROJECT_ROOT}/scripts/task_23_download_odinw_dataset.sh" "${DOWNLOAD_ARGS[@]}"
                    DOWNLOAD_EXIT_CODE=$?
                    
                    if [ ${DOWNLOAD_EXIT_CODE} -eq 0 ]; then
                        echo ""
                        echo "✓ Dataset download completed. Re-running validation..."
                        echo ""
                        # Re-run validation
                        uv run python scripts/task_62_config_validation.py "${VALIDATE_ARGS[@]}"
                        REVALIDATION_EXIT_CODE=$?
                        if [ ${REVALIDATION_EXIT_CODE} -eq 0 ]; then
                            echo "✓ Validation passed after dataset download!"
                            echo ""
                        else
                            echo "⚠ Validation still failed after download. Please check the errors above."
                            exit 1
                        fi
                    else
                        echo ""
                        echo "ERROR: Dataset download failed (exit code: ${DOWNLOAD_EXIT_CODE})"
                        echo "Please download the dataset manually or check the errors above."
                        exit 1
                    fi
                # Offer to download if running interactively
                elif [ -t 0 ] && [ -t 1 ]; then
                    echo "Would you like to download the ODinW dataset now? (y/n)"
                    read -r response
                    if [[ "${response}" =~ ^[Yy]$ ]]; then
                        echo ""
                        echo "Downloading missing ODinW datasets..."
                        echo "----------------------------------------"
                        # Use --missing-only to only download what's needed
                        DOWNLOAD_ARGS=("--missing-only" "--config" "${RESOLVED_CONFIG}")
                        if [ -n "${ODINW_ROOT:-${ODINW_DATA_ROOT:-}}" ]; then
                            DOWNLOAD_ARGS+=("${ODINW_ROOT:-${ODINW_DATA_ROOT:-}}")
                        fi
                        bash "${PROJECT_ROOT}/scripts/task_23_download_odinw_dataset.sh" "${DOWNLOAD_ARGS[@]}"
                        DOWNLOAD_EXIT_CODE=$?
                        
                        if [ ${DOWNLOAD_EXIT_CODE} -eq 0 ]; then
                            echo ""
                            echo "✓ Dataset download completed. Re-running validation..."
                            echo ""
                            # Re-run validation
                            uv run python scripts/task_62_config_validation.py "${VALIDATE_ARGS[@]}"
                            REVALIDATION_EXIT_CODE=$?
                            if [ ${REVALIDATION_EXIT_CODE} -eq 0 ]; then
                                echo "✓ Validation passed after dataset download!"
                                echo ""
                            else
                                echo "⚠ Validation still failed after download. Please check the errors above."
                                exit 1
                            fi
                        else
                            echo ""
                            echo "ERROR: Dataset download failed (exit code: ${DOWNLOAD_EXIT_CODE})"
                            echo "Please download the dataset manually or check the errors above."
                            exit 1
                        fi
                    else
                        echo ""
                        echo "Skipping download. You can download later using:"
                        echo "  bash scripts/task_23_download_odinw_dataset.sh"
                        echo ""
                        echo "Or set ODINW_DATA_ROOT environment variable to your dataset location."
                        echo ""
                        echo "Note: You can skip validation with --skip-config-validation,"
                        echo "      or use --auto-download to automatically download missing datasets."
                        exit 1
                    fi
                else
                    # Non-interactive mode - just show instructions
                    echo "Quick fix - Download ODinW dataset:"
                    echo "  bash scripts/task_23_download_odinw_dataset.sh"
                    echo ""
                    echo "Or re-run with --auto-download flag to download automatically:"
                    echo "  ./train_odinw.sh --auto-download"
                    echo ""
                    echo "Or set ODINW_DATA_ROOT environment variable to your dataset location."
                    echo ""
                    echo "Note: You can skip validation with --skip-config-validation,"
                    echo "      but training will likely fail if files are missing."
                    exit 1
                fi
            else
                echo "Common issues:"
                echo "  - ODinW dataset not downloaded or incomplete"
                echo "  - Annotation files missing (e.g., annotations_without_background.json)"
                echo "  - Dataset path incorrect"
                echo ""
                echo "To fix:"
                echo "  1. Download ODinW dataset (follow GLIP instructions)"
                echo "  2. Set ODINW_DATA_ROOT to the correct path"
                echo "  3. Or use --skip-config-validation to proceed anyway (not recommended)"
                exit 1
            fi
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
echo "Note: ODinW uses job arrays for training all supercategories."
echo "Each task in the array trains on one supercategory."
echo ""

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

if [ -n "${ODINW_ROOT}" ]; then
    TRAINING_ARGS+=(--odinw-root "${ODINW_ROOT}")
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
        echo "Config type: ${CONFIG_TYPE}"
        echo "Monitor training progress using TensorBoard or check logs."
        echo ""
        echo "Note: ODinW training uses job arrays. Each array task trains"
        echo "      on one supercategory from all_odinw_supercategories."
    else
        echo ""
        echo "ERROR: Training launch failed (exit code: ${TRAINING_EXIT_CODE})" >&2
        exit ${TRAINING_EXIT_CODE}
    fi
fi

