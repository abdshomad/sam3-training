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

# Check if GLIP submodule exists and is initialized
if [ ! -d "glip/odinw" ]; then
    echo "ERROR: GLIP submodule not found or not initialized"
    echo ""
    echo "The GLIP submodule is required to download ODinW datasets."
    echo "Please run: git submodule update --init --recursive"
    echo ""
    exit 1
fi

# Default download path (convert to absolute path)
if [ -n "${ODINW_DATA_ROOT:-}" ]; then
    DOWNLOAD_PATH="${ODINW_DATA_ROOT}"
elif [ -n "${1:-}" ]; then
    DOWNLOAD_PATH="${1}"
else
    DOWNLOAD_PATH="${PROJECT_ROOT}/data/odinw"
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
echo ""

# Check if dataset already exists and has content
if [ -d "${DOWNLOAD_PATH}" ] && [ -n "$(ls -A "${DOWNLOAD_PATH}" 2>/dev/null)" ]; then
    echo "✓ Dataset directory already exists and contains data: ${DOWNLOAD_PATH}"
    echo "  Skipping download."
    echo ""
    echo "Dataset location: ${DOWNLOAD_PATH}"
    echo ""
    echo "If you want to re-download, remove the directory first:"
    echo "  rm -rf ${DOWNLOAD_PATH}"
    echo ""
    exit 0
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
echo "Starting ODinW dataset download..."
echo "This may take a while depending on your internet connection..."
echo "Downloading all ODinW datasets to: ${DOWNLOAD_PATH}"
echo ""

# Change to glip directory to run the download script
cd glip

# Run the download script using uv run python (per workspace rules)
if command -v uv &> /dev/null; then
    uv run python odinw/download.py --dataset_path "${DOWNLOAD_PATH}" --dataset_names all
else
    # Fallback to system python if uv is not available
    uv run python odinw/download.py --dataset_path "${DOWNLOAD_PATH}" --dataset_names all
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

