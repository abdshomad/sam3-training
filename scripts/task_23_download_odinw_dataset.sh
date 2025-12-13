#!/bin/bash
# Task ID: 2.3
# Description: Download ODinW Dataset
# Created: 2025-12-13

set -e

echo "=========================================="
echo "Task 2.3: Download ODinW Dataset"
echo "=========================================="

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Change to project root
cd "${PROJECT_ROOT}"

# Initialize variables
DOWNLOAD_PATH=""
MISSING_ONLY=false
CONFIG_FILE=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --missing-only)
            MISSING_ONLY=true
            shift
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --help|-h)
            cat << EOF
Usage: $0 [OPTIONS] [DOWNLOAD_PATH]

Download ODinW datasets.

Arguments:
  DOWNLOAD_PATH              Path where datasets will be downloaded
                            (default: ./data/odinw or ODINW_DATA_ROOT)

Options:
  --missing-only            Only download datasets with missing annotation files
                            Requires --config to check which files are needed
  --config PATH             Config file to check for required datasets
                            (required when using --missing-only)
  --help, -h                Show this help message

Environment Variables:
  ODINW_DATA_ROOT           Default download path

Examples:
  # Download all datasets
  $0

  # Download only missing datasets (requires config)
  $0 --missing-only --config sam3/sam3/train/configs/odinw13/odinw_text_only_train.yaml

  # Download to custom path
  $0 /path/to/odinw/data
EOF
            exit 0
            ;;
        *)
            if [ -z "${DOWNLOAD_PATH}" ]; then
                DOWNLOAD_PATH="$1"
            else
                echo "ERROR: Unknown option or multiple paths: $1" >&2
                echo "Use --help for usage information" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if GLIP submodule exists and is initialized
if [ ! -d "glip/odinw" ]; then
    echo "ERROR: GLIP submodule not found or not initialized"
    echo ""
    echo "The GLIP submodule is required to download ODinW datasets."
    echo "Please run: git submodule update --init --recursive"
    echo ""
    exit 1
fi

# Set default download path if not provided
if [ -z "${DOWNLOAD_PATH}" ]; then
    if [ -n "${ODINW_DATA_ROOT:-}" ]; then
        DOWNLOAD_PATH="${ODINW_DATA_ROOT}"
    else
        DOWNLOAD_PATH="${PROJECT_ROOT}/data/odinw"
    fi
fi

# Convert to absolute path if relative (remove leading ./ if present)
if [[ ! "${DOWNLOAD_PATH}" = /* ]]; then
    # Remove leading ./ if present
    DOWNLOAD_PATH="${DOWNLOAD_PATH#./}"
    DOWNLOAD_PATH="${PROJECT_ROOT}/${DOWNLOAD_PATH}"
fi

echo ""
echo "Download configuration:"
echo "  Download path: ${DOWNLOAD_PATH}"
if [ "${MISSING_ONLY}" = true ]; then
    echo "  Mode: Missing files only"
    if [ -n "${CONFIG_FILE}" ]; then
        echo "  Config file: ${CONFIG_FILE}"
    fi
fi
echo ""

# Handle missing-only mode
if [ "${MISSING_ONLY}" = true ]; then
    if [ -z "${CONFIG_FILE}" ]; then
        echo "ERROR: --config is required when using --missing-only" >&2
        echo "Please specify a config file to check for required datasets" >&2
        echo "Example: $0 --missing-only --config sam3/sam3/train/configs/odinw13/odinw_text_only_train.yaml" >&2
        exit 1
    fi
    
    # Resolve config file path
    if [[ ! "${CONFIG_FILE}" = /* ]]; then
        CONFIG_FILE="${PROJECT_ROOT}/${CONFIG_FILE#./}"
    fi
    
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo "ERROR: Config file not found: ${CONFIG_FILE}" >&2
        exit 1
    fi
    
    echo "Analyzing config to find missing datasets..."
    echo "----------------------------------------"
    
    # Use Python to find missing datasets
    MISSING_DATASETS=$(uv run python -c "
import yaml
import sys
from pathlib import Path

config_path = Path('${CONFIG_FILE}')
odinw_root = Path('${DOWNLOAD_PATH}')

with open(config_path, 'r') as f:
    config = yaml.safe_load(f)

all_supercategories = config.get('all_odinw_supercategories', [])
if not all_supercategories:
    print('No all_odinw_supercategories found in config', file=sys.stderr)
    sys.exit(1)

# Map supercategory names to dataset names
# e.g., 'AerialMaritimeDrone_large' -> 'AerialMaritimeDrone'
# e.g., 'EgoHands_generic' -> 'EgoHands'
def get_dataset_name(supercat_name):
    # Remove suffixes like '_large', '_generic', etc.
    if '_' in supercat_name:
        return supercat_name.split('_')[0]
    return supercat_name

missing_datasets = set()
for supercat in all_supercategories:
    if isinstance(supercat, dict):
        name = supercat.get('name', '')
        val_info = supercat.get('val', {})
        json_path = val_info.get('json', '')
        
        if json_path:
            full_path = odinw_root / json_path
            if not full_path.exists():
                dataset_name = get_dataset_name(name)
                missing_datasets.add(dataset_name)

if missing_datasets:
    print(','.join(sorted(missing_datasets)))
else:
    print('all')  # If nothing is missing, download all (shouldn't happen)
" 2>&1)
    
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to analyze config file" >&2
        exit 1
    fi
    
    if [ "${MISSING_DATASETS}" = "all" ]; then
        echo "✓ All required datasets are already present"
        echo "  No download needed."
        exit 0
    fi
    
    echo "Found missing datasets: ${MISSING_DATASETS}"
    echo ""
    DATASET_NAMES="${MISSING_DATASETS}"
else
    # Check if dataset already exists and has content (only for full download)
    if [ -d "${DOWNLOAD_PATH}" ] && [ -n "$(ls -A "${DOWNLOAD_PATH}" 2>/dev/null)" ]; then
        echo "✓ Dataset directory already exists and contains data: ${DOWNLOAD_PATH}"
        echo "  Skipping download."
        echo ""
        echo "Dataset location: ${DOWNLOAD_PATH}"
        echo ""
        echo "If you want to re-download, remove the directory first:"
        echo "  rm -rf ${DOWNLOAD_PATH}"
        echo ""
        echo "Or use --missing-only to download only missing files:"
        echo "  $0 --missing-only --config <config_file>"
        echo ""
        exit 0
    fi
    DATASET_NAMES="all"
fi

# Create download directory
mkdir -p "${DOWNLOAD_PATH}"

# Check if wget is available
if ! command -v wget &> /dev/null; then
    echo "ERROR: wget is not installed"
    echo "Please install wget to download ODinW datasets:"
    echo "  Ubuntu/Debian: sudo apt-get install wget"
    echo "  macOS: brew install wget"
    echo ""
    exit 1
fi

# Check if unzip is available
if ! command -v unzip &> /dev/null; then
    echo "ERROR: unzip is not installed"
    echo "Please install unzip to extract ODinW datasets:"
    echo "  Ubuntu/Debian: sudo apt-get install unzip"
    echo "  macOS: brew install unzip"
    echo ""
    exit 1
fi

# Download the datasets using GLIP's download script
if [ "${MISSING_ONLY}" = true ]; then
    echo "Starting ODinW dataset download (missing files only)..."
    echo "Downloading datasets: ${DATASET_NAMES}"
else
    echo "Starting ODinW dataset download..."
    echo "Downloading all ODinW datasets"
fi
echo "This may take a while depending on your internet connection..."
echo "Download path: ${DOWNLOAD_PATH}"
echo ""

# Change to glip directory to run the download script
cd glip

# Run the download script using uv run python (per workspace rules)
if command -v uv &> /dev/null; then
    uv run python odinw/download.py --dataset_path "${DOWNLOAD_PATH}" --dataset_names "${DATASET_NAMES}"
else
    # Fallback to system python if uv is not available
    uv run python odinw/download.py --dataset_path "${DOWNLOAD_PATH}" --dataset_names "${DATASET_NAMES}"
fi

cd ..

echo ""
echo "=========================================="
echo "ODinW dataset download completed!"
echo "=========================================="
echo ""
echo "Dataset location: ${DOWNLOAD_PATH}"
echo ""
echo "Next steps:"
echo "1. Verify the dataset structure matches the expected format"
echo "2. Update your config file with the correct odinw_data_root path"
echo "3. Run validation: ./scripts/task_24_validate_data_directory_structure.sh --dataset-type odinw"
echo "4. Run training with ODinW configs:"
echo "   uv run python -m sam3.train.train -c configs/odinw13/odinw_text_only_train.yaml --use-cluster 0 --num-gpus 2"
echo ""

exit 0

