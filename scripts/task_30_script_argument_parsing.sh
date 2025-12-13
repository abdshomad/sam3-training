#!/bin/bash
# Task ID: 3.0
# Description: Script Argument Parsing
# Created: 2025-12-12

set -e

echo "=========================================="
echo "Task 3.0: Script Argument Parsing"
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

# Initialize variables (matching sam3/train/train.py arguments)
CONFIG_ARG=""
USE_CLUSTER=""
PARTITION=""
ACCOUNT=""
QOS=""
NUM_GPUS=""
NUM_NODES=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_ARG="$2"
            shift 2
            ;;
        --use-cluster)
            USE_CLUSTER="$2"
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
        --num-gpus)
            NUM_GPUS="$2"
            shift 2
            ;;
        --num-nodes)
            NUM_NODES="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -c, --config PATH         Config file path (optional)"
            echo "                            Examples:"
            echo "                              configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml"
            echo "                              roboflow_v100/roboflow_v100_full_ft_100_images.yaml"
            echo ""
            echo "Optional Options:"
            echo "  --use-cluster VALUE       Whether to launch on cluster (0: local, 1: cluster)"
            echo "  --partition NAME          SLURM partition name for cluster execution"
            echo "  --account NAME            SLURM account name for cluster execution"
            echo "  --qos NAME                SLURM QOS (Quality of Service) setting"
            echo "  --num-gpus N              Number of GPUs per node (positive integer)"
            echo "  --num-nodes N             Number of nodes for distributed training (positive integer)"
            echo "  -h, --help                Show this help message"
            echo ""
            echo "This script parses and validates arguments for sam3/train/train.py"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Config argument is optional - script can run without it
# (useful for testing argument parsing logic)

# Validate --use-cluster if provided
if [ -n "${USE_CLUSTER}" ]; then
    if [[ ! "${USE_CLUSTER}" =~ ^[01]$ ]]; then
        echo "ERROR: --use-cluster must be 0 (local) or 1 (cluster)"
        echo "Got: ${USE_CLUSTER}"
        exit 1
    fi
fi

# Validate --num-gpus if provided
if [ -n "${NUM_GPUS}" ]; then
    if [[ ! "${NUM_GPUS}" =~ ^[1-9][0-9]*$ ]]; then
        echo "ERROR: --num-gpus must be a positive integer"
        echo "Got: ${NUM_GPUS}"
        exit 1
    fi
fi

# Validate --num-nodes if provided
if [ -n "${NUM_NODES}" ]; then
    if [[ ! "${NUM_NODES}" =~ ^[1-9][0-9]*$ ]]; then
        echo "ERROR: --num-nodes must be a positive integer"
        echo "Got: ${NUM_NODES}"
        exit 1
    fi
fi

# Validate cluster-specific arguments
if [ -n "${USE_CLUSTER}" ] && [ "${USE_CLUSTER}" = "1" ]; then
    if [ -z "${PARTITION}" ] && [ -z "${ACCOUNT}" ]; then
        echo "WARNING: Cluster mode enabled but no partition or account specified"
        echo "These may be required depending on your SLURM configuration"
    fi
fi

# If cluster mode is not explicitly set but cluster args are provided, warn
if [ -z "${USE_CLUSTER}" ] && ([ -n "${PARTITION}" ] || [ -n "${ACCOUNT}" ] || [ -n "${QOS}" ]); then
    echo "WARNING: Cluster-specific arguments provided but --use-cluster not set"
    echo "These arguments will be ignored unless --use-cluster 1 is specified"
fi

echo ""
echo "Parsed arguments:"
if [ -n "${CONFIG_ARG}" ]; then
    echo "  Config: ${CONFIG_ARG}"
else
    echo "  Config: Not specified"
fi
if [ -n "${USE_CLUSTER}" ]; then
    if [ "${USE_CLUSTER}" = "0" ]; then
        echo "  Use Cluster: No (local mode)"
    else
        echo "  Use Cluster: Yes (cluster mode)"
    fi
else
    echo "  Use Cluster: Not specified (will use config default)"
fi
if [ -n "${PARTITION}" ]; then
    echo "  Partition: ${PARTITION}"
fi
if [ -n "${ACCOUNT}" ]; then
    echo "  Account: ${ACCOUNT}"
fi
if [ -n "${QOS}" ]; then
    echo "  QOS: ${QOS}"
fi
if [ -n "${NUM_GPUS}" ]; then
    echo "  Num GPUs: ${NUM_GPUS}"
fi
if [ -n "${NUM_NODES}" ]; then
    echo "  Num Nodes: ${NUM_NODES}"
fi
echo ""

# Export parsed variables for use by subsequent scripts
export SAM3_CONFIG_ARG="${CONFIG_ARG}"
if [ -n "${USE_CLUSTER}" ]; then
    export SAM3_USE_CLUSTER="${USE_CLUSTER}"
fi
if [ -n "${PARTITION}" ]; then
    export SAM3_PARTITION="${PARTITION}"
fi
if [ -n "${ACCOUNT}" ]; then
    export SAM3_ACCOUNT="${ACCOUNT}"
fi
if [ -n "${QOS}" ]; then
    export SAM3_QOS="${QOS}"
fi
if [ -n "${NUM_GPUS}" ]; then
    export SAM3_NUM_GPUS="${NUM_GPUS}"
fi
if [ -n "${NUM_NODES}" ]; then
    export SAM3_NUM_NODES="${NUM_NODES}"
fi

echo "Argument parsing completed successfully!"
echo ""

exit 0

