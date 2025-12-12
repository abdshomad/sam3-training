#!/bin/bash
# Task ID: 4.0
# Description: Execution Logic Construction
# Created: 2025-12-12

set -e

echo "=========================================="
echo "Task 4.0: Execution Logic Construction"
echo "=========================================="

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Change to project root
cd "${PROJECT_ROOT}"

# Initialize command components
BASE_CMD="python -m sam3.train.train"
CONFIG_ARG=""
USE_CLUSTER=""
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
            USE_CLUSTER="$2"
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
            echo "This script constructs the training command from arguments and environment variables."
            echo ""
            echo "Options (override environment variables if set):"
            echo "  -c, --config PATH         Config file path (required if not in SAM3_CONFIG_ARG)"
            echo "  --use-cluster VALUE       Whether to launch on cluster (0: local, 1: cluster)"
            echo "  --num-gpus N              Number of GPUs per node"
            echo "  --num-nodes N             Number of nodes for distributed training"
            echo "  --partition NAME          SLURM partition name (cluster mode only)"
            echo "  --account NAME            SLURM account name (cluster mode only)"
            echo "  --qos NAME                SLURM QOS setting (cluster mode only)"
            echo ""
            echo "Environment Variables (from previous scripts):"
            echo "  SAM3_CONFIG_ARG           Config file path"
            echo "  SAM3_USE_CLUSTER          Cluster mode (0 or 1)"
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

if [ -z "${USE_CLUSTER}" ] && [ -n "${SAM3_USE_CLUSTER}" ]; then
    USE_CLUSTER="${SAM3_USE_CLUSTER}"
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
    echo "  $0 -c configs/roboflow_v100/roboflow_v100_full_ft_100_images-copy.yaml --use-cluster 0 --num-gpus 2"
    echo ""
    echo "Skipping command construction (no config provided)."
    exit 0
fi

# Normalize config path: ensure it starts with "configs/" for Hydra
# Hydra expects configs relative to the sam3.train package configs directory
if [[ ! "${CONFIG_ARG}" =~ ^configs/ ]]; then
    CONFIG_ARG="configs/${CONFIG_ARG}"
    echo "Normalized config path to: ${CONFIG_ARG}"
fi

# Validate config file exists
# After normalization, CONFIG_ARG always starts with "configs/"
CONFIG_PATH="${PROJECT_ROOT}/sam3/sam3/train/${CONFIG_ARG}"

if [ ! -f "${CONFIG_PATH}" ]; then
    echo "WARNING: Config file not found at: ${CONFIG_PATH}"
    echo "The command will be constructed, but may fail at runtime"
    echo "Expected location: ${CONFIG_PATH}"
fi

# Build the command
CMD="${BASE_CMD} -c ${CONFIG_ARG}"

# Add --use-cluster if provided
if [ -n "${USE_CLUSTER}" ]; then
    CMD="${CMD} --use-cluster ${USE_CLUSTER}"
fi

# Add --num-gpus if provided
if [ -n "${NUM_GPUS}" ]; then
    CMD="${CMD} --num-gpus ${NUM_GPUS}"
fi

# Add --num-nodes if provided
if [ -n "${NUM_NODES}" ]; then
    CMD="${CMD} --num-nodes ${NUM_NODES}"
fi

# Add cluster-specific arguments (only if cluster mode)
if [ -n "${USE_CLUSTER}" ] && [ "${USE_CLUSTER}" = "1" ]; then
    if [ -n "${PARTITION}" ]; then
        CMD="${CMD} --partition ${PARTITION}"
    fi
    if [ -n "${ACCOUNT}" ]; then
        CMD="${CMD} --account ${ACCOUNT}"
    fi
    if [ -n "${QOS}" ]; then
        CMD="${CMD} --qos ${QOS}"
    fi
elif [ -n "${PARTITION}" ] || [ -n "${ACCOUNT}" ] || [ -n "${QOS}" ]; then
    echo "WARNING: Cluster-specific arguments provided but not in cluster mode"
    echo "These arguments will be ignored unless --use-cluster 1 is set"
fi

echo ""
echo "Constructed command:"
echo "  ${CMD}"
echo ""

# Display command breakdown
echo "Command breakdown:"
echo "  Base: ${BASE_CMD}"
echo "  Config: ${CONFIG_ARG}"
if [ -n "${USE_CLUSTER}" ]; then
    echo "  Use Cluster: ${USE_CLUSTER}"
fi
if [ -n "${NUM_GPUS}" ]; then
    echo "  Num GPUs: ${NUM_GPUS}"
fi
if [ -n "${NUM_NODES}" ]; then
    echo "  Num Nodes: ${NUM_NODES}"
fi
if [ -n "${USE_CLUSTER}" ] && [ "${USE_CLUSTER}" = "1" ]; then
    if [ -n "${PARTITION}" ]; then
        echo "  Partition: ${PARTITION}"
    fi
    if [ -n "${ACCOUNT}" ]; then
        echo "  Account: ${ACCOUNT}"
    fi
    if [ -n "${QOS}" ]; then
        echo "  QOS: ${QOS}"
    fi
fi
echo ""

# Export the constructed command
export SAM3_TRAIN_COMMAND="${CMD}"

echo "Command construction completed successfully!"
echo ""
echo "To execute, run:"
echo "  ${CMD}"
echo ""
echo "Or use the exported variable:"
echo "  eval \${SAM3_TRAIN_COMMAND}"
echo ""

exit 0

