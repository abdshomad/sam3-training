#!/bin/bash
# Task ID: 2.5
# Description: Config File Existence Check
# Created: 2025-12-12

set -e

echo "=========================================="
echo "Task 2.5: Config File Existence Check"
echo "=========================================="

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Change to project root
cd "${PROJECT_ROOT}"

# Initialize variables
CONFIG_ARG=""
CONFIG_PATH=""
CONFIGS_DIR="${PROJECT_ROOT}/sam3/sam3/train/configs"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_ARG="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -c, --config PATH    Config file path (required)"
            echo "                       Examples:"
            echo "                         configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml"
            echo "                         roboflow_v100/roboflow_v100_full_ft_100_images.yaml"
            echo "                         roboflow_v100/roboflow_v100_full_ft_100_images"
            echo "  -h, --help          Show this help message"
            echo ""
            echo "This script validates that the specified config file exists in"
            echo "sam3/sam3/train/configs/ directory."
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate configs directory exists
if [ ! -d "${CONFIGS_DIR}" ]; then
    echo "ERROR: Configs directory does not exist: ${CONFIGS_DIR}"
    exit 1
fi

# If no config argument provided, list available configs and exit successfully
if [ -z "${CONFIG_ARG}" ]; then
    echo ""
    echo "No config file specified. Listing available config files:"
    echo ""
    
    # List available configs
    CONFIG_COUNT=0
    find "${CONFIGS_DIR}" -name "*.yaml" -type f | sort | while read -r file; do
        RELATIVE_PATH="${file#${CONFIGS_DIR}/}"
        echo "  - ${RELATIVE_PATH}"
        CONFIG_COUNT=$((CONFIG_COUNT + 1))
    done
    
    echo ""
    echo "Use -c or --config to validate a specific config file."
    echo "Example: $0 -c configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml"
    echo ""
    echo "Config file listing completed successfully!"
    echo ""
    exit 0
fi

# Check if config path is absolute and exists
if [[ "${CONFIG_ARG}" =~ ^/ ]]; then
    # Absolute path - check if it exists directly
    if [ -f "${CONFIG_ARG}" ]; then
        CONFIG_PATH="${CONFIG_ARG}"
        NORMALIZED_CONFIG="$(basename "${CONFIG_ARG}")"
        echo ""
        echo "Checking config file..."
        echo "  Input: ${CONFIG_ARG}"
        echo "  Type: Absolute path"
        echo "  Full path: ${CONFIG_PATH}"
        echo ""
        echo "✓ Config file exists: ${CONFIG_PATH}"
        echo ""
        echo "Config file validation completed successfully!"
        echo ""
        
        # Export for use by subsequent scripts
        export SAM3_CONFIG_PATH="${CONFIG_PATH}"
        export SAM3_CONFIG_NAME="${NORMALIZED_CONFIG}"
        
        exit 0
    else
        # Absolute path doesn't exist - try with .yaml extension if missing
        if [[ ! "${CONFIG_ARG}" =~ \.yaml$ ]]; then
            CONFIG_PATH="${CONFIG_ARG}.yaml"
            if [ -f "${CONFIG_PATH}" ]; then
                NORMALIZED_CONFIG="$(basename "${CONFIG_PATH}")"
                echo ""
                echo "Checking config file..."
                echo "  Input: ${CONFIG_ARG}"
                echo "  Type: Absolute path (added .yaml extension)"
                echo "  Full path: ${CONFIG_PATH}"
                echo ""
                echo "✓ Config file exists: ${CONFIG_PATH}"
                echo ""
                echo "Config file validation completed successfully!"
                echo ""
                
                # Export for use by subsequent scripts
                export SAM3_CONFIG_PATH="${CONFIG_PATH}"
                export SAM3_CONFIG_NAME="${NORMALIZED_CONFIG}"
                
                exit 0
            fi
        fi
        # Absolute path doesn't exist - show error
        echo ""
        echo "Checking config file..."
        echo "  Input: ${CONFIG_ARG}"
        echo "  Type: Absolute path"
        echo "  Full path: ${CONFIG_ARG}"
        echo ""
        echo "ERROR: Config file does not exist: ${CONFIG_ARG}"
        echo ""
        exit 1
    fi
fi

# Relative path - normalize and check in CONFIGS_DIR
# Remove leading "configs/" if present
NORMALIZED_CONFIG="${CONFIG_ARG#configs/}"
# Remove leading "/" if present
NORMALIZED_CONFIG="${NORMALIZED_CONFIG#/}"

# Ensure .yaml extension
if [[ ! "${NORMALIZED_CONFIG}" =~ \.yaml$ ]]; then
    NORMALIZED_CONFIG="${NORMALIZED_CONFIG}.yaml"
fi

# Construct full path
CONFIG_PATH="${CONFIGS_DIR}/${NORMALIZED_CONFIG}"

echo ""
echo "Checking config file..."
echo "  Input: ${CONFIG_ARG}"
echo "  Normalized: ${NORMALIZED_CONFIG}"
echo "  Full path: ${CONFIG_PATH}"
echo ""

# Check if file exists
if [ ! -f "${CONFIG_PATH}" ]; then
    echo "ERROR: Config file does not exist: ${CONFIG_PATH}"
    echo ""
    echo "Available config files in ${CONFIGS_DIR}:"
    echo ""
    
    # List available configs
    find "${CONFIGS_DIR}" -name "*.yaml" -type f | sort | while read -r file; do
        RELATIVE_PATH="${file#${CONFIGS_DIR}/}"
        echo "  - ${RELATIVE_PATH}"
    done
    
    echo ""
    exit 1
fi

# Convert to absolute path for clarity
CONFIG_PATH="$(cd "$(dirname "${CONFIG_PATH}")" && pwd)/$(basename "${CONFIG_PATH}")"

echo "✓ Config file exists: ${CONFIG_PATH}"
echo ""
echo "Config file validation completed successfully!"
echo ""

# Export for use by subsequent scripts
export SAM3_CONFIG_PATH="${CONFIG_PATH}"
export SAM3_CONFIG_NAME="${NORMALIZED_CONFIG}"

exit 0

