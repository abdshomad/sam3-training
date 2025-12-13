#!/bin/bash
# Task ID: 2.1
# Description: Define Data Root Variables
# Created: 2025-12-12

set -e

echo "=========================================="
echo "Task 2.1: Define Data Root Variables"
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
fi

# Initialize variables (will be set from CLI args or env vars)
ROBOFLOW_ROOT=""
ODINW_ROOT=""

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
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --roboflow-root PATH    Path to Roboflow VL-100 dataset root"
            echo "  --odinw-root PATH       Path to ODinW dataset root"
            echo "  -h, --help              Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  ROBOFLOW_VL_100_ROOT   Path to Roboflow VL-100 dataset root"
            echo "  ODINW_DATA_ROOT         Path to ODinW dataset root"
            echo ""
            echo "Priority: CLI arguments > Environment variables"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Use CLI args if provided, otherwise fall back to environment variables
# Priority: CLI args > env vars
if [ -z "${ROBOFLOW_ROOT}" ]; then
    if [ -n "${ROBOFLOW_VL_100_ROOT:-}" ]; then
        ROBOFLOW_ROOT="${ROBOFLOW_VL_100_ROOT}"
        echo "Using ROBOFLOW_VL_100_ROOT from environment variable"
    fi
fi

if [ -z "${ODINW_ROOT}" ]; then
    if [ -n "${ODINW_DATA_ROOT:-}" ]; then
        ODINW_ROOT="${ODINW_DATA_ROOT}"
        echo "Using ODINW_DATA_ROOT from environment variable"
    fi
fi

# Validate that paths exist and are directories (if provided)
# Convert relative paths to absolute before validation
if [ -n "${ROBOFLOW_ROOT}" ]; then
    # Convert to absolute path first (handles both relative and absolute)
    if [[ ! "${ROBOFLOW_ROOT}" =~ ^/ ]]; then
        # Relative path - resolve from project root
        ROBOFLOW_ROOT="${PROJECT_ROOT}/${ROBOFLOW_ROOT#./}"
    fi
    # Normalize path (remove trailing slashes, resolve . and ..)
    ROBOFLOW_ROOT="$(cd "${ROBOFLOW_ROOT}" 2>/dev/null && pwd || echo "${ROBOFLOW_ROOT}")"
    
    if [ ! -d "${ROBOFLOW_ROOT}" ]; then
        echo "Note: Roboflow root path does not exist yet (will be created on download): ${ROBOFLOW_ROOT}"
        echo "  This is normal if datasets haven't been downloaded yet."
    else
        echo "✓ Roboflow VL-100 root: ${ROBOFLOW_ROOT}"
    fi
else
    echo "Note: Roboflow VL-100 root not specified (optional)"
fi

if [ -n "${ODINW_ROOT}" ]; then
    # Convert to absolute path first (handles both relative and absolute)
    if [[ ! "${ODINW_ROOT}" =~ ^/ ]]; then
        # Relative path - resolve from project root
        ODINW_ROOT="${PROJECT_ROOT}/${ODINW_ROOT#./}"
    fi
    # Normalize path (remove trailing slashes, resolve . and ..)
    ODINW_ROOT="$(cd "${ODINW_ROOT}" 2>/dev/null && pwd || echo "${ODINW_ROOT}")"
    
    if [ ! -d "${ODINW_ROOT}" ]; then
        echo "Note: ODinW root path does not exist yet (will be created on download): ${ODINW_ROOT}"
        echo "  This is normal if datasets haven't been downloaded yet."
    else
        echo "✓ ODinW data root: ${ODINW_ROOT}"
    fi
else
    echo "Note: ODinW data root not specified (optional)"
fi

# Export variables for use by subsequent scripts
if [ -n "${ROBOFLOW_ROOT}" ]; then
    export ROBOFLOW_VL_100_ROOT="${ROBOFLOW_ROOT}"
fi

if [ -n "${ODINW_ROOT}" ]; then
    export ODINW_DATA_ROOT="${ODINW_ROOT}"
fi

echo ""
echo "Data root variables defined successfully."
echo ""
