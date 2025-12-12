#!/bin/bash
# Task ID: 3.1
# Description: Implement Mode Selection (Local vs. Cluster)
# Created: 2025-12-12

set -e

echo "=========================================="
echo "Task 3.1: Implement Mode Selection"
echo "=========================================="

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Change to project root
cd "${PROJECT_ROOT}"

# Initialize variables
MODE=""
USE_CLUSTER=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            MODE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --mode MODE           Execution mode: 'local' or 'cluster' (required)"
            echo "                         - 'local': Run training locally (maps to --use-cluster 0)"
            echo "                         - 'cluster': Run training on cluster (maps to --use-cluster 1)"
            echo "  -h, --help            Show this help message"
            echo ""
            echo "This script converts the user-friendly --mode flag to the"
            echo "--use-cluster argument expected by sam3/train/train.py"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate that mode argument was provided
if [ -z "${MODE}" ]; then
    echo "ERROR: Mode is required"
    echo "Use --mode to specify 'local' or 'cluster'"
    echo "Use --help for usage information"
    exit 1
fi

# Normalize mode to lowercase
MODE="$(echo "${MODE}" | tr '[:upper:]' '[:lower:]')"

# Validate mode value
if [ "${MODE}" != "local" ] && [ "${MODE}" != "cluster" ]; then
    echo "ERROR: Invalid mode: ${MODE}"
    echo "Mode must be either 'local' or 'cluster'"
    exit 1
fi

# Map mode to use-cluster value
if [ "${MODE}" = "local" ]; then
    USE_CLUSTER="0"
    MODE_DESCRIPTION="Local execution (single node)"
elif [ "${MODE}" = "cluster" ]; then
    USE_CLUSTER="1"
    MODE_DESCRIPTION="Cluster execution (SLURM)"
fi

echo ""
echo "Mode selection:"
echo "  Input mode: ${MODE}"
echo "  Mapped to: --use-cluster ${USE_CLUSTER}"
echo "  Description: ${MODE_DESCRIPTION}"
echo ""

# Export for use by subsequent scripts
export SAM3_MODE="${MODE}"
export SAM3_USE_CLUSTER="${USE_CLUSTER}"

echo "Mode selection completed successfully!"
echo ""

exit 0

