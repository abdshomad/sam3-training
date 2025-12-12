#!/bin/bash
# Task ID: 3.2
# Description: Implement Resource Allocation Flags
# Created: 2025-12-12

set -e

echo "=========================================="
echo "Task 3.2: Implement Resource Allocation Flags"
echo "=========================================="

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Change to project root
cd "${PROJECT_ROOT}"

# Initialize variables for resource allocation
NUM_GPUS=""
NUM_NODES=""
PARTITION=""
ACCOUNT=""
QOS=""
USE_CLUSTER=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
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
        --use-cluster)
            USE_CLUSTER="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Resource Allocation Options:"
            echo "  --num-gpus N              Number of GPUs per node (positive integer)"
            echo "  --num-nodes N             Number of nodes for distributed training (positive integer)"
            echo ""
            echo "Cluster-Specific Options (require --use-cluster 1):"
            echo "  --partition NAME          SLURM partition name for cluster execution"
            echo "  --account NAME            SLURM account name for cluster execution"
            echo "  --qos NAME                SLURM QOS (Quality of Service) setting"
            echo ""
            echo "Mode Option:"
            echo "  --use-cluster VALUE       Whether to launch on cluster (0: local, 1: cluster)"
            echo "                            Required to validate cluster-specific arguments"
            echo ""
            echo "  -h, --help                Show this help message"
            echo ""
            echo "This script validates and exports resource allocation arguments"
            echo "for sam3/train/train.py"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

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
    echo "Validated: --num-gpus ${NUM_GPUS}"
fi

# Validate --num-nodes if provided
if [ -n "${NUM_NODES}" ]; then
    if [[ ! "${NUM_NODES}" =~ ^[1-9][0-9]*$ ]]; then
        echo "ERROR: --num-nodes must be a positive integer"
        echo "Got: ${NUM_NODES}"
        exit 1
    fi
    echo "Validated: --num-nodes ${NUM_NODES}"
fi

# Validate cluster-specific arguments
if [ -n "${PARTITION}" ] || [ -n "${ACCOUNT}" ] || [ -n "${QOS}" ]; then
    if [ -z "${USE_CLUSTER}" ]; then
        echo "WARNING: Cluster-specific arguments provided but --use-cluster not set"
        echo "These arguments (--partition, --account, --qos) are only used in cluster mode"
        echo "Consider adding --use-cluster 1 if you intend to run on a cluster"
    elif [ "${USE_CLUSTER}" = "0" ]; then
        echo "WARNING: Cluster-specific arguments provided but --use-cluster 0 (local mode)"
        echo "These arguments will be ignored in local mode"
    else
        # Cluster mode is enabled, validate cluster args
        if [ -n "${PARTITION}" ]; then
            echo "Validated: --partition ${PARTITION}"
        fi
        if [ -n "${ACCOUNT}" ]; then
            echo "Validated: --account ${ACCOUNT}"
        fi
        if [ -n "${QOS}" ]; then
            echo "Validated: --qos ${QOS}"
        fi
        
        # Warn if cluster mode but no partition/account
        if [ -z "${PARTITION}" ] && [ -z "${ACCOUNT}" ]; then
            echo "WARNING: Cluster mode enabled but no partition or account specified"
            echo "These may be required depending on your SLURM configuration"
        fi
    fi
fi

echo ""
echo "Resource allocation summary:"
if [ -n "${NUM_GPUS}" ]; then
    echo "  Num GPUs: ${NUM_GPUS}"
else
    echo "  Num GPUs: Not specified (will use config default)"
fi
if [ -n "${NUM_NODES}" ]; then
    echo "  Num Nodes: ${NUM_NODES}"
else
    echo "  Num Nodes: Not specified (will use config default)"
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
if [ -n "${USE_CLUSTER}" ]; then
    if [ "${USE_CLUSTER}" = "0" ]; then
        echo "  Mode: Local"
    else
        echo "  Mode: Cluster"
    fi
fi
echo ""

# Export parsed variables for use by subsequent scripts
if [ -n "${NUM_GPUS}" ]; then
    export SAM3_NUM_GPUS="${NUM_GPUS}"
fi
if [ -n "${NUM_NODES}" ]; then
    export SAM3_NUM_NODES="${NUM_NODES}"
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
if [ -n "${USE_CLUSTER}" ]; then
    export SAM3_USE_CLUSTER="${USE_CLUSTER}"
fi

echo "Resource allocation flags processed successfully!"
echo ""

exit 0

