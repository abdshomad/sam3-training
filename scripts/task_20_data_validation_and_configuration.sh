#!/bin/bash
# Task ID: 2.0
# Description: Data Validation and Configuration
# Created: 2025-12-12

set -e

echo "=========================================="
echo "Task 2.0: Data Validation and Configuration"
echo "=========================================="

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Change to project root
cd "${PROJECT_ROOT}"

# Parse arguments to pass through to sub-tasks
ROBOFLOW_ROOT=""
ODINW_ROOT=""
DATASET_TYPE="both"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --roboflow-root)
            ROBOFLOW_ROOT="$2"
            shift 2
            ;;
        --odinw-root)
            ODINW_ROOT="$2"
            shift 2
            ;;
        --dataset-type)
            DATASET_TYPE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --roboflow-root PATH    Path to Roboflow VL-100 dataset root"
            echo "  --odinw-root PATH       Path to ODinW dataset root"
            echo "  --dataset-type TYPE     Dataset type to validate: roboflow, odinw, or both (default: both)"
            echo "  -h, --help              Show this help message"
            echo ""
            echo "This script orchestrates:"
            echo "  - Task 2.1: Define Data Root Variables"
            echo "  - Task 2.2: Validate Data Directory Structure"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo ""
echo "This script will:"
echo "  1. Define data root variables (Task 2.1)"
echo "  2. Validate data directory structure (Task 2.2)"
echo ""

# Step 1: Define Data Root Variables (Task 2.1)
echo "Step 1: Defining data root variables..."
BUILD_ARGS=()
if [ -n "${ROBOFLOW_ROOT}" ]; then
    BUILD_ARGS+=(--roboflow-root "${ROBOFLOW_ROOT}")
fi
if [ -n "${ODINW_ROOT}" ]; then
    BUILD_ARGS+=(--odinw-root "${ODINW_ROOT}")
fi

"${SCRIPT_DIR}/task_21_define_data_root_variables.sh" "${BUILD_ARGS[@]}"
if [ $? -ne 0 ]; then
    echo "ERROR: Data root variables definition failed"
    exit 1
fi

echo ""

# Step 2: Validate Data Directory Structure (Task 2.2)
echo "Step 2: Validating data directory structure..."
VALIDATION_ARGS=(--dataset-type "${DATASET_TYPE}")

"${SCRIPT_DIR}/task_22_validate_data_directory_structure.sh" "${VALIDATION_ARGS[@]}"
if [ $? -ne 0 ]; then
    echo "ERROR: Data directory structure validation failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "Data validation and configuration completed successfully!"
echo "=========================================="
echo ""

