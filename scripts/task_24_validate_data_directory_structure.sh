#!/bin/bash
# Task ID: 2.4
# Description: Validate Data Directory Structure - Validates both rf100vl and ODinW datasets
# Created: 2025-12-12

set -e

echo "=========================================="
echo "Task 2.4: Validate Data Directory Structure"
echo "=========================================="

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Change to project root
cd "${PROJECT_ROOT}"

# Initialize variables
DATASET_TYPE="both"  # Default: validate both if roots are available

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dataset-type)
            DATASET_TYPE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dataset-type TYPE     Dataset type to validate: roboflow, odinw, or both (default: both)"
            echo "  -h, --help              Show this help message"
            echo ""
            echo "Environment Variables (from task 2.1):"
            echo "  ROBOFLOW_VL_100_ROOT   Path to Roboflow VL-100 dataset root"
            echo "  ODINW_DATA_ROOT         Path to ODinW dataset root"
            echo ""
            echo "This script validates both rf100vl and ODinW datasets:"
            echo "  - rf100vl: Checks for dataset directories, train/valid/test splits, and annotation files"
            echo "  - ODinW: Checks for supercategory directories, proper structure, and annotation files"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate dataset type
if [[ ! "${DATASET_TYPE}" =~ ^(roboflow|odinw|both)$ ]]; then
    echo "ERROR: Invalid dataset type: ${DATASET_TYPE}"
    echo "Must be one of: roboflow, odinw, both"
    exit 1
fi

VALIDATION_FAILED=0

# This script validates both rf100vl and ODinW datasets:
# - rf100vl validation: Checks for dataset directories, train/valid/test splits, and annotation files
# - ODinW validation: Checks for supercategory directories, proper structure, and annotation files
# Validation can be performed for one or both datasets based on --dataset-type parameter

# Function to validate Roboflow directory structure
validate_roboflow_structure() {
    local ROBOFLOW_ROOT="${ROBOFLOW_VL_100_ROOT:-}"
    
    if [ -z "${ROBOFLOW_ROOT}" ]; then
        echo "Note: Roboflow root not set, skipping Roboflow validation"
        return 0
    fi
    
    if [ ! -d "${ROBOFLOW_ROOT}" ]; then
        echo "ERROR: Roboflow root directory does not exist: ${ROBOFLOW_ROOT}"
        return 1
    fi
    
    echo ""
    echo "Validating Roboflow VL-100 directory structure..."
    echo "Root: ${ROBOFLOW_ROOT}"
    
    # Check if root contains any subdirectories (supercategories)
    if [ -z "$(ls -A "${ROBOFLOW_ROOT}" 2>/dev/null)" ]; then
        echo "ERROR: Roboflow root directory is empty: ${ROBOFLOW_ROOT}"
        return 1
    fi
    
    # Find at least one valid supercategory structure
    FOUND_VALID_STRUCTURE=0
    ERRORS=0
    
    # Check each subdirectory in the root
    for SUPERCATEGORY in "${ROBOFLOW_ROOT}"/*; do
        if [ ! -d "${SUPERCATEGORY}" ]; then
            continue
        fi
        
        SUPERCATEGORY_NAME="$(basename "${SUPERCATEGORY}")"
        
        # Check for train directory
        TRAIN_DIR="${SUPERCATEGORY}/train"
        if [ ! -d "${TRAIN_DIR}" ]; then
            echo "  WARNING: Missing train/ directory in ${SUPERCATEGORY_NAME}"
            ERRORS=$((ERRORS + 1))
            continue
        fi
        
        # Check for test directory
        TEST_DIR="${SUPERCATEGORY}/test"
        if [ ! -d "${TEST_DIR}" ]; then
            echo "  WARNING: Missing test/ directory in ${SUPERCATEGORY_NAME}"
            ERRORS=$((ERRORS + 1))
            continue
        fi
        
        # Check for annotation file in train directory
        ANNOTATION_FILE="${TRAIN_DIR}/_annotations.coco.json"
        if [ ! -f "${ANNOTATION_FILE}" ]; then
            echo "  WARNING: Missing _annotations.coco.json in ${SUPERCATEGORY_NAME}/train/"
            ERRORS=$((ERRORS + 1))
            continue
        fi
        
        # Check for annotation file in test directory
        TEST_ANNOTATION_FILE="${TEST_DIR}/_annotations.coco.json"
        if [ ! -f "${TEST_ANNOTATION_FILE}" ]; then
            echo "  WARNING: Missing _annotations.coco.json in ${SUPERCATEGORY_NAME}/test/"
            ERRORS=$((ERRORS + 1))
            continue
        fi
        
        # If we get here, this supercategory has valid structure
        if [ ${FOUND_VALID_STRUCTURE} -eq 0 ]; then
            echo "  ✓ Found valid structure in ${SUPERCATEGORY_NAME}"
            FOUND_VALID_STRUCTURE=1
        fi
    done
    
    if [ ${FOUND_VALID_STRUCTURE} -eq 0 ]; then
        echo "ERROR: No valid Roboflow supercategory structure found"
        echo "Expected structure: {root}/{supercategory}/train/ and {root}/{supercategory}/test/"
        echo "Each should contain _annotations.coco.json"
        return 1
    fi
    
    if [ ${ERRORS} -gt 0 ]; then
        echo "  WARNING: Found ${ERRORS} issues in Roboflow structure (some supercategories may be incomplete)"
    else
        echo "  ✓ Roboflow directory structure is valid"
    fi
    
    return 0
}

# Function to validate ODinW directory structure
validate_odinw_structure() {
    local ODINW_ROOT="${ODINW_DATA_ROOT:-}"
    
    if [ -z "${ODINW_ROOT}" ]; then
        echo "Note: ODinW root not set, skipping ODinW validation"
        return 0
    fi
    
    if [ ! -d "${ODINW_ROOT}" ]; then
        echo "ERROR: ODinW root directory does not exist: ${ODINW_ROOT}"
        return 1
    fi
    
    echo ""
    echo "Validating ODinW directory structure..."
    echo "Root: ${ODINW_ROOT}"
    
    # Check if root contains any subdirectories (supercategories)
    if [ -z "$(ls -A "${ODINW_ROOT}" 2>/dev/null)" ]; then
        echo "ERROR: ODinW root directory is empty: ${ODINW_ROOT}"
        return 1
    fi
    
    # Find at least one valid supercategory structure
    FOUND_VALID_STRUCTURE=0
    ERRORS=0
    
    # Check each subdirectory in the root
    for SUPERCATEGORY in "${ODINW_ROOT}"/*; do
        if [ ! -d "${SUPERCATEGORY}" ]; then
            continue
        fi
        
        SUPERCATEGORY_NAME="$(basename "${SUPERCATEGORY}")"
        
        # Check for large/train directory structure
        LARGE_DIR="${SUPERCATEGORY}/large"
        if [ ! -d "${LARGE_DIR}" ]; then
            # Some supercategories might not have 'large' subdirectory
            # Check if train/valid/test exist directly
            TRAIN_DIR="${SUPERCATEGORY}/train"
            VALID_DIR="${SUPERCATEGORY}/valid"
            TEST_DIR="${SUPERCATEGORY}/test"
            
            if [ -d "${TRAIN_DIR}" ] || [ -d "${VALID_DIR}" ] || [ -d "${TEST_DIR}" ]; then
                # Found valid structure without 'large' subdirectory
                if [ ${FOUND_VALID_STRUCTURE} -eq 0 ]; then
                    echo "  ✓ Found valid structure in ${SUPERCATEGORY_NAME} (without large/)"
                    FOUND_VALID_STRUCTURE=1
                fi
                continue
            else
                echo "  WARNING: ${SUPERCATEGORY_NAME} does not have expected structure (no large/ or train/valid/test/)"
                ERRORS=$((ERRORS + 1))
                continue
            fi
        fi
        
        # Check for train directory
        TRAIN_DIR="${LARGE_DIR}/train"
        if [ ! -d "${TRAIN_DIR}" ]; then
            echo "  WARNING: Missing large/train/ directory in ${SUPERCATEGORY_NAME}"
            ERRORS=$((ERRORS + 1))
            continue
        fi
        
        # Check for valid directory
        VALID_DIR="${LARGE_DIR}/valid"
        if [ ! -d "${VALID_DIR}" ]; then
            echo "  WARNING: Missing large/valid/ directory in ${SUPERCATEGORY_NAME}"
            ERRORS=$((ERRORS + 1))
            continue
        fi
        
        # Check for test directory
        TEST_DIR="${LARGE_DIR}/test"
        if [ ! -d "${TEST_DIR}" ]; then
            echo "  WARNING: Missing large/test/ directory in ${SUPERCATEGORY_NAME}"
            ERRORS=$((ERRORS + 1))
            continue
        fi
        
        # If we get here, this supercategory has valid structure
        if [ ${FOUND_VALID_STRUCTURE} -eq 0 ]; then
            echo "  ✓ Found valid structure in ${SUPERCATEGORY_NAME}/large/"
            FOUND_VALID_STRUCTURE=1
        fi
    done
    
    if [ ${FOUND_VALID_STRUCTURE} -eq 0 ]; then
        echo "ERROR: No valid ODinW supercategory structure found"
        echo "Expected structure: {root}/{supercategory}/large/train/, valid/, test/"
        echo "Or: {root}/{supercategory}/train/, valid/, test/"
        return 1
    fi
    
    if [ ${ERRORS} -gt 0 ]; then
        echo "  WARNING: Found ${ERRORS} issues in ODinW structure (some supercategories may be incomplete)"
    else
        echo "  ✓ ODinW directory structure is valid"
    fi
    
    return 0
}

# Perform validation based on dataset type
# Validates both rf100vl and ODinW datasets when dataset-type is "both"
if [ "${DATASET_TYPE}" = "roboflow" ] || [ "${DATASET_TYPE}" = "both" ]; then
    echo "Validating rf100vl dataset structure..."
    if ! validate_roboflow_structure; then
        VALIDATION_FAILED=1
    fi
fi

if [ "${DATASET_TYPE}" = "odinw" ] || [ "${DATASET_TYPE}" = "both" ]; then
    echo "Validating ODinW dataset structure..."
    if ! validate_odinw_structure; then
        VALIDATION_FAILED=1
    fi
fi

echo ""
if [ ${VALIDATION_FAILED} -eq 0 ]; then
    echo "=========================================="
    echo "Data directory structure validation completed successfully!"
    if [ "${DATASET_TYPE}" = "both" ]; then
        echo "Both rf100vl and ODinW datasets validated successfully!"
    fi
    echo "=========================================="
    echo ""
    exit 0
else
    echo "=========================================="
    echo "Data directory structure validation failed!"
    echo "=========================================="
    echo ""
    exit 1
fi

