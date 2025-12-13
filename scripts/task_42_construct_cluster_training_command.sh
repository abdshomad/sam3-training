#!/bin/bash
# Task ID: 4.2
# Description: Construct Cluster Training Command
# Created: 2025-12-12

set -e

echo "=========================================="
echo "Task 4.2: Construct Cluster Training Command"
echo "=========================================="

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Change to project root
cd "${PROJECT_ROOT}"

# Load environment variables from .env file if it exists
if [ -f "${PROJECT_ROOT}/.env" ]; then
    set -a  # Automatically export all variables
    source "${PROJECT_ROOT}/.env"
    set +a  # Turn off automatic export

# Load RF100-VL specific environment variables from .env.rf100vl if it exists
if [ -f "${PROJECT_ROOT}/.env.rf100vl" ]; then
    set -a  # Automatically export all variables
    source "${PROJECT_ROOT}/.env.rf100vl"
    set +a  # Turn off automatic export
fi
fi

# Initialize command components
BASE_CMD="uv run python -m sam3.train.train"
CONFIG_ARG=""
USE_CLUSTER="1"
NUM_GPUS=""
NUM_NODES=""
PARTITION=""
ACCOUNT=""
QOS=""

# Parse command-line arguments (can override environment variables)
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_ARG="$2"
            shift 2
            ;;
        --use-cluster)
            if [ "$2" != "1" ]; then
                echo "WARNING: This script is for cluster mode (--use-cluster 1)"
                echo "Received --use-cluster $2, forcing to 1 for cluster execution"
            fi
            USE_CLUSTER="1"
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
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Constructs a cluster training command with SLURM validation."
            echo ""
            echo "Options:"
            echo "  -c, --config PATH         Config file path (required)"
            echo "  --use-cluster VALUE       Ignored (always set to 1 for cluster mode)"
            echo "  --num-gpus N              Number of GPUs per node"
            echo "  --num-nodes N             Number of nodes for distributed training"
            echo "  --partition NAME          SLURM partition name (recommended)"
            echo "  --account NAME            SLURM account name (recommended)"
            echo "  --qos NAME                SLURM QOS setting (optional)"
            echo ""
            echo "Environment Variables (from previous scripts):"
            echo "  SAM3_CONFIG_ARG           Config file path"
            echo "  SAM3_NUM_GPUS             Number of GPUs"
            echo "  SAM3_NUM_NODES            Number of nodes"
            echo "  SAM3_PARTITION            SLURM partition"
            echo "  SAM3_ACCOUNT              SLURM account"
            echo "  SAM3_QOS                  SLURM QOS"
            echo ""
            echo "  -h, --help                Show this help message"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Use environment variables if command-line args not provided
if [ -z "${CONFIG_ARG}" ] && [ -n "${SAM3_CONFIG_ARG}" ]; then
    CONFIG_ARG="${SAM3_CONFIG_ARG}"
fi
if [ -z "${CONFIG_ARG}" ] && [ -n "${SAM3_CONFIG_SUGGESTION}" ]; then
    CONFIG_ARG="${SAM3_CONFIG_SUGGESTION}"
    echo "Using suggested config: ${CONFIG_ARG}"
fi

if [ -z "${NUM_GPUS}" ] && [ -n "${SAM3_NUM_GPUS}" ]; then
    NUM_GPUS="${SAM3_NUM_GPUS}"
fi

if [ -z "${NUM_NODES}" ] && [ -n "${SAM3_NUM_NODES}" ]; then
    NUM_NODES="${SAM3_NUM_NODES}"
fi

if [ -z "${PARTITION}" ] && [ -n "${SAM3_PARTITION}" ]; then
    PARTITION="${SAM3_PARTITION}"
fi

if [ -z "${ACCOUNT}" ] && [ -n "${SAM3_ACCOUNT}" ]; then
    ACCOUNT="${SAM3_ACCOUNT}"
fi

if [ -z "${QOS}" ] && [ -n "${SAM3_QOS}" ]; then
    QOS="${SAM3_QOS}"
fi

# Validate required config argument
if [ -z "${CONFIG_ARG}" ]; then
    echo "WARNING: Config file path is not provided"
    echo ""
    echo "To use this script, provide a config via:"
    echo "  - Command line: -c/--config PATH"
    echo "  - Environment: SAM3_CONFIG_ARG"
    echo "  - Previous script: task_33_implement_task_type_selection.sh --task-type train|eval"
    echo ""
    echo "Example:"
    echo "  $0 -c configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml --partition gpu_partition --account my_account --num-gpus 8"
    echo ""
    echo "Skipping cluster training command construction (no config provided)."
    exit 0
fi

# Normalize config path: ensure it starts with "configs/" for Hydra
if [[ ! "${CONFIG_ARG}" =~ ^configs/ ]]; then
    CONFIG_ARG="configs/${CONFIG_ARG}"
    echo "Normalized config path to: ${CONFIG_ARG}"
fi

# Validate config file exists
CONFIG_PATH="${PROJECT_ROOT}/sam3/sam3/train/${CONFIG_ARG}"

if [ ! -f "${CONFIG_PATH}" ]; then
    echo "ERROR: Config file not found at: ${CONFIG_PATH}"
    echo "Please verify the config path is correct."
    exit 1
fi

echo "✓ Config file validated: ${CONFIG_PATH}"

# Validate SLURM availability
echo ""
echo "Validating SLURM availability for cluster training..."

if ! command -v sbatch &> /dev/null; then
    echo "WARNING: sbatch command not found. SLURM may not be available."
    echo "Training command will be constructed, but may fail at runtime if SLURM is required."
    SLURM_AVAILABLE=0
else
    echo "✓ SLURM commands available (sbatch found)"
    SLURM_AVAILABLE=1
    
    # Optionally check partition availability if sinfo is available
    if command -v sinfo &> /dev/null && [ -n "${PARTITION}" ]; then
        if sinfo -p "${PARTITION}" &> /dev/null; then
            echo "✓ Partition '${PARTITION}' is available"
        else
            echo "WARNING: Partition '${PARTITION}' not found or not accessible"
            echo "Run 'sinfo' to see available partitions"
        fi
    fi
fi

# Check for required SLURM parameters (warn if missing, but don't fail)
if [ -z "${PARTITION}" ]; then
    echo "WARNING: --partition not specified. Job may fail or use default partition."
    echo "Recommend specifying --partition for cluster training."
fi

if [ -z "${ACCOUNT}" ]; then
    echo "WARNING: --account not specified. Job may fail if account is required."
    echo "Recommend specifying --account for cluster training."
fi

# Build the cluster training command
CMD="${BASE_CMD} -c ${CONFIG_ARG} --use-cluster ${USE_CLUSTER}"

# Add --num-gpus if provided
if [ -n "${NUM_GPUS}" ]; then
    CMD="${CMD} --num-gpus ${NUM_GPUS}"
fi

# Add --num-nodes if provided
if [ -n "${NUM_NODES}" ]; then
    CMD="${CMD} --num-nodes ${NUM_NODES}"
fi

# Add cluster-specific arguments
if [ -n "${PARTITION}" ]; then
    CMD="${CMD} --partition ${PARTITION}"
fi

if [ -n "${ACCOUNT}" ]; then
    CMD="${CMD} --account ${ACCOUNT}"
fi

if [ -n "${QOS}" ]; then
    CMD="${CMD} --qos ${QOS}"
fi

echo ""
echo "=========================================="
echo "Constructed Cluster Training Command:"
echo "=========================================="
echo "  ${CMD}"
echo ""

# Display command breakdown
echo "Command breakdown:"
echo "  Base: ${BASE_CMD}"
echo "  Config: ${CONFIG_ARG}"
echo "  Use Cluster: ${USE_CLUSTER} (cluster mode)"
if [ -n "${NUM_GPUS}" ]; then
    echo "  Num GPUs: ${NUM_GPUS}"
else
    echo "  Num GPUs: (from config/default)"
fi
if [ -n "${NUM_NODES}" ]; then
    echo "  Num Nodes: ${NUM_NODES}"
else
    echo "  Num Nodes: (from config/default)"
fi
if [ -n "${PARTITION}" ]; then
    echo "  Partition: ${PARTITION}"
else
    echo "  Partition: (not specified, may use default)"
fi
if [ -n "${ACCOUNT}" ]; then
    echo "  Account: ${ACCOUNT}"
else
    echo "  Account: (not specified, may be required)"
fi
if [ -n "${QOS}" ]; then
    echo "  QOS: ${QOS}"
else
    echo "  QOS: (not specified, using default)"
fi
echo ""

# Export the constructed command
export SAM3_TRAIN_COMMAND="${CMD}"
export SAM3_USE_CLUSTER="${USE_CLUSTER}"

echo "Cluster training command construction completed successfully!"
echo ""
echo "To execute, run:"
echo "  ${CMD}"
echo ""
echo "Or use the exported variable:"
echo "  eval \${SAM3_TRAIN_COMMAND}"
echo ""
if [ "${SLURM_AVAILABLE}" -eq 1 ]; then
    echo "Note: This will submit a SLURM job. Monitor with:"
    echo "  squeue -u \$USER"
    echo ""
fi

exit 0

