#!/bin/bash
# Task ID: 4.1
# Description: Construct Local Training Command
# Created: 2025-12-12

set -e

echo "=========================================="
echo "Task 4.1: Construct Local Training Command"
echo "=========================================="

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Change to project root
cd "${PROJECT_ROOT}"

# Check if virtual environment is active (reuse logic from task 1.1)
if [ -z "${VIRTUAL_ENV}" ] && [ -z "${CONDA_DEFAULT_ENV}" ]; then
    if [ ! -f ".venv/bin/activate" ]; then
        echo "WARNING: No virtual environment detected!"
        echo "Recommend activating a virtual environment before running training."
    else
        echo "Note: Using .venv directory (consider activating: source .venv/bin/activate)"
    fi
else
    echo "✓ Virtual environment active"
fi

# Initialize command components
BASE_CMD="python -m sam3.train.train"
CONFIG_ARG=""
NUM_GPUS=""
USE_CLUSTER="0"

# Parse command-line arguments (can override environment variables)
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_ARG="$2"
            shift 2
            ;;
        --num-gpus)
            NUM_GPUS="$2"
            shift 2
            ;;
        --use-cluster)
            if [ "$2" != "0" ]; then
                echo "WARNING: This script is for local mode (--use-cluster 0)"
                echo "Received --use-cluster $2, forcing to 0 for local execution"
            fi
            USE_CLUSTER="0"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Constructs a local training command with GPU validation."
            echo ""
            echo "Options:"
            echo "  -c, --config PATH         Config file path (required)"
            echo "  --num-gpus N              Number of GPUs per node (default: from config/env)"
            echo "  --use-cluster VALUE       Ignored (always set to 0 for local mode)"
            echo ""
            echo "Environment Variables (from previous scripts):"
            echo "  SAM3_CONFIG_ARG           Config file path"
            echo "  SAM3_NUM_GPUS             Number of GPUs"
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
    echo "  $0 -c configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml --num-gpus 2"
    echo ""
    echo "Skipping local training command construction (no config provided)."
    exit 0
fi

# Normalize config path: ensure it starts with "configs/" for Hydra
if [[ ! "${CONFIG_ARG}" =~ ^configs/ ]]; then
    CONFIG_ARG="configs/${CONFIG_ARG}"
    echo "Normalized config path to: ${CONFIG_ARG}"
fi

# Validate config file exists (reuse logic from task 2.4)
CONFIG_PATH="${PROJECT_ROOT}/sam3/sam3/train/${CONFIG_ARG}"

if [ ! -f "${CONFIG_PATH}" ]; then
    echo "ERROR: Config file not found at: ${CONFIG_PATH}"
    echo "Please verify the config path is correct."
    exit 1
fi

echo "✓ Config file validated: ${CONFIG_PATH}"

# GPU validation if GPUs are requested
if [ -n "${NUM_GPUS}" ] && [ "${NUM_GPUS}" -gt 0 ]; then
    echo ""
    echo "Validating GPU availability for local training..."
    
    # Check if nvidia-smi is available
    if ! command -v nvidia-smi &> /dev/null; then
        echo "WARNING: nvidia-smi not found. Cannot validate GPU availability."
        echo "Training may fail if GPUs are required."
    else
        # Get available GPU count
        AVAILABLE_GPUS=$(nvidia-smi --list-gpus | wc -l)
        echo "✓ Available GPUs: ${AVAILABLE_GPUS}"
        
        # Validate requested GPUs don't exceed available
        if [ "${NUM_GPUS}" -gt "${AVAILABLE_GPUS}" ]; then
            echo "ERROR: Requested ${NUM_GPUS} GPUs, but only ${AVAILABLE_GPUS} available"
            echo "Please reduce --num-gpus or use fewer GPUs."
            exit 1
        fi
        
        echo "✓ Requested GPUs (${NUM_GPUS}) within available (${AVAILABLE_GPUS})"
        
        # Check CUDA availability
        if python -c "import torch; print(torch.cuda.is_available())" 2>/dev/null | grep -q "True"; then
            echo "✓ CUDA is available in PyTorch"
        else
            echo "WARNING: CUDA not available in PyTorch. GPU training may not work."
        fi
    fi
fi

# Build the local training command
CMD="${BASE_CMD} -c ${CONFIG_ARG} --use-cluster ${USE_CLUSTER}"

# Add --num-gpus if provided
if [ -n "${NUM_GPUS}" ]; then
    CMD="${CMD} --num-gpus ${NUM_GPUS}"
fi

echo ""
echo "=========================================="
echo "Constructed Local Training Command:"
echo "=========================================="
echo "  ${CMD}"
echo ""

# Display command breakdown
echo "Command breakdown:"
echo "  Base: ${BASE_CMD}"
echo "  Config: ${CONFIG_ARG}"
echo "  Use Cluster: ${USE_CLUSTER} (local mode)"
if [ -n "${NUM_GPUS}" ]; then
    echo "  Num GPUs: ${NUM_GPUS}"
else
    echo "  Num GPUs: (from config/default)"
fi
echo ""

# Export the constructed command
export SAM3_TRAIN_COMMAND="${CMD}"
export SAM3_USE_CLUSTER="${USE_CLUSTER}"

echo "Local training command construction completed successfully!"
echo ""
echo "To execute, run:"
echo "  ${CMD}"
echo ""
echo "Or use the exported variable:"
echo "  eval \${SAM3_TRAIN_COMMAND}"
echo ""

exit 0

