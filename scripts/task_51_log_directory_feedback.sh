#!/bin/bash
# Task ID: 5.1
# Description: Log Directory Feedback
# Created: 2025-12-13

set -e

echo "=========================================="
echo "Task 5.1: Log Directory Feedback"
echo "=========================================="

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Change to project root
cd "${PROJECT_ROOT}"

EXPERIMENT_LOG_DIR=""
INPUT_FILE=""
CONFIG_ARG=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --log-dir)
            EXPERIMENT_LOG_DIR="$2"
            shift 2
            ;;
        --input-file|-i)
            INPUT_FILE="$2"
            shift 2
            ;;
        --config|-c)
            CONFIG_ARG="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Extracts and displays the experiment log directory location."
            echo ""
            echo "Options:"
            echo "  --log-dir PATH           Directly specify experiment log directory"
            echo "  --input-file PATH, -i    Parse log directory from training output file"
            echo "  --config PATH, -c        Extract log directory from config file"
            echo ""
            echo "Environment Variables:"
            echo "  SAM3_EXPERIMENT_LOG_DIR  Experiment log directory (if already extracted)"
            echo "  SAM3_CONFIG_ARG          Config file path (for fallback)"
            echo ""
            echo "  -h, --help               Show this help message"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Try to get log directory from various sources
if [ -n "${EXPERIMENT_LOG_DIR}" ]; then
    # Use directly provided log directory
    echo "Using provided log directory: ${EXPERIMENT_LOG_DIR}"
elif [ -n "${SAM3_EXPERIMENT_LOG_DIR}" ]; then
    # Use environment variable
    EXPERIMENT_LOG_DIR="${SAM3_EXPERIMENT_LOG_DIR}"
    echo "Using log directory from environment: ${EXPERIMENT_LOG_DIR}"
elif [ -n "${INPUT_FILE}" ] && [ -f "${INPUT_FILE}" ]; then
    # Parse from training output file
    echo "Parsing log directory from training output: ${INPUT_FILE}"
    # Look for "Experiment Log Dir:" followed by the path on the next line
    # The format is: "Experiment Log Dir:\n{path}"
    EXPERIMENT_LOG_DIR=$(grep -A 1 "Experiment Log Dir:" "${INPUT_FILE}" | tail -n 1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -z "${EXPERIMENT_LOG_DIR}" ]; then
        echo "WARNING: Could not extract log directory from input file"
    else
        echo "Extracted log directory: ${EXPERIMENT_LOG_DIR}"
    fi
elif [ -n "${CONFIG_ARG}" ]; then
    # Parse from config file
    echo "Extracting log directory from config file: ${CONFIG_ARG}"
    CONFIG_PATH="${PROJECT_ROOT}/sam3/sam3/train/${CONFIG_ARG}"
    if [ ! -f "${CONFIG_PATH}" ]; then
        # Try without normalization
        CONFIG_PATH="${CONFIG_ARG}"
        if [ ! -f "${CONFIG_PATH}" ]; then
            echo "ERROR: Config file not found: ${CONFIG_ARG}"
            exit 1
        fi
    fi
    
    # Try to extract using Python (more reliable for YAML)
    if command -v python3 &> /dev/null || command -v python &> /dev/null; then
        PYTHON_CMD=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
        # Use environment variables to pass arguments and avoid ${ expansion issues
        export CONFIG_PATH_ENV="${CONFIG_PATH}"
        export PROJECT_ROOT_ENV="${PROJECT_ROOT}"
        EXPERIMENT_LOG_DIR=$(${PYTHON_CMD} << 'PYTHON_SCRIPT'
import sys
import os
import yaml
from pathlib import Path

config_path = os.environ['CONFIG_PATH_ENV']
project_root = os.environ['PROJECT_ROOT_ENV']

try:
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f)
    
    # Try launcher.experiment_log_dir first
    log_dir = config.get('launcher', {}).get('experiment_log_dir')
    
    # If it's a reference like ${paths.experiment_log_dir}, resolve it
    # Use chr() to construct ${ without triggering bash expansion
    dollar_brace = chr(36) + chr(123)  # ${
    if isinstance(log_dir, str) and log_dir.startswith(dollar_brace) and log_dir.endswith('}'):
        # Extract the reference path (e.g., ${paths.experiment_log_dir} -> paths.experiment_log_dir)
        ref_str = log_dir[2:-1]  # Remove ${ and }
        ref_path = ref_str.split('.')
        if len(ref_path) == 2 and ref_path[0] == 'paths':
            log_dir = config.get('paths', {}).get(ref_path[1])
    
    # If still not found, try paths.experiment_log_dir directly
    if not log_dir:
        log_dir = config.get('paths', {}).get('experiment_log_dir')
    
    # If still not found, construct default path
    if not log_dir:
        config_name = Path(config_path).stem
        log_dir = str(Path(project_root) / 'sam3_logs' / config_name)
    
    if log_dir:
        print(log_dir)
    else:
        sys.exit(1)
except Exception as e:
    sys.exit(1)
PYTHON_SCRIPT
) 2>/dev/null
        
        if [ -z "${EXPERIMENT_LOG_DIR}" ]; then
            echo "WARNING: Could not extract log directory from config file"
        fi
    else
        echo "WARNING: Python not available, cannot parse YAML config"
    fi
elif [ -n "${SAM3_CONFIG_ARG}" ]; then
    # Use config from environment variable
    CONFIG_ARG="${SAM3_CONFIG_ARG}"
    # Recursively call with --config
    "$0" --config "${CONFIG_ARG}"
    exit $?
fi

# If still no log directory found, show warning and exit gracefully
if [ -z "${EXPERIMENT_LOG_DIR}" ]; then
    echo "WARNING: Could not determine experiment log directory"
    echo ""
    echo "Please provide one of:"
    echo "  --log-dir PATH           Direct path to log directory"
    echo "  --input-file PATH        Training output file to parse"
    echo "  --config PATH            Config file to extract from"
    echo "  SAM3_EXPERIMENT_LOG_DIR  Environment variable"
    echo ""
    echo "This script requires arguments to function. Exiting gracefully."
    exit 0
fi

# Convert to absolute path if relative
if [[ ! "${EXPERIMENT_LOG_DIR}" =~ ^/ ]]; then
    EXPERIMENT_LOG_DIR="$(cd "$(dirname "${EXPERIMENT_LOG_DIR}")" && pwd)/$(basename "${EXPERIMENT_LOG_DIR}")"
fi

echo ""
echo "=========================================="
echo "Experiment Log Directory Information"
echo "=========================================="
echo ""

# Display the main log directory
echo "Experiment Log Directory:"
echo "  ${EXPERIMENT_LOG_DIR}"
echo ""

# Check if directory exists
if [ ! -d "${EXPERIMENT_LOG_DIR}" ]; then
    echo "⚠ WARNING: Log directory does not exist yet (training may not have started)"
    echo ""
else
    echo "✓ Log directory exists"
    echo ""
fi

# Display key file locations
echo "Key Files and Directories:"
echo ""

# Check for config.yaml
CONFIG_YAML="${EXPERIMENT_LOG_DIR}/config.yaml"
if [ -f "${CONFIG_YAML}" ]; then
    echo "  ✓ config.yaml: ${CONFIG_YAML}"
else
    echo "  ⚠ config.yaml: ${CONFIG_YAML} (not found yet)"
fi

# Check for config_resolved.yaml
CONFIG_RESOLVED="${EXPERIMENT_LOG_DIR}/config_resolved.yaml"
if [ -f "${CONFIG_RESOLVED}" ]; then
    echo "  ✓ config_resolved.yaml: ${CONFIG_RESOLVED}"
else
    echo "  ⚠ config_resolved.yaml: ${CONFIG_RESOLVED} (not found yet)"
fi

# Check for checkpoints directory
CHECKPOINTS_DIR="${EXPERIMENT_LOG_DIR}/checkpoints"
if [ -d "${CHECKPOINTS_DIR}" ]; then
    CHECKPOINT_COUNT=$(find "${CHECKPOINTS_DIR}" -name "*.pt" -o -name "*.pth" 2>/dev/null | wc -l)
    echo "  ✓ checkpoints/: ${CHECKPOINTS_DIR} (${CHECKPOINT_COUNT} checkpoint(s))"
else
    echo "  ⚠ checkpoints/: ${CHECKPOINTS_DIR} (not found yet)"
fi

# Check for tensorboard directory
TENSORBOARD_DIR="${EXPERIMENT_LOG_DIR}/tensorboard"
if [ -d "${TENSORBOARD_DIR}" ]; then
    echo "  ✓ tensorboard/: ${TENSORBOARD_DIR}"
else
    echo "  ⚠ tensorboard/: ${TENSORBOARD_DIR} (not found yet)"
fi

# Check for logs directory
LOGS_DIR="${EXPERIMENT_LOG_DIR}/logs"
if [ -d "${LOGS_DIR}" ]; then
    echo "  ✓ logs/: ${LOGS_DIR}"
else
    echo "  ⚠ logs/: ${LOGS_DIR} (not found yet)"
fi

# Check for submitit_logs directory (cluster mode)
SUBMITIT_DIR="${EXPERIMENT_LOG_DIR}/submitit_logs"
if [ -d "${SUBMITIT_DIR}" ]; then
    echo "  ✓ submitit_logs/: ${SUBMITIT_DIR}"
fi

echo ""

# Export for downstream scripts
export SAM3_EXPERIMENT_LOG_DIR="${EXPERIMENT_LOG_DIR}"

echo "Log directory information extracted successfully!"
echo ""

exit 0

