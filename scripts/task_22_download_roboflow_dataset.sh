#!/bin/bash
# Task ID: 2.2
# Description: Download Roboflow Dataset
# Created: 2025-12-12

set -e

echo "=========================================="
echo "Task 2.2: Download Roboflow Dataset"
echo "=========================================="

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Change to project root
cd "${PROJECT_ROOT}"

# Check if submodule is initialized
if [ ! -d "rf100-vl/rf100vl" ]; then
    echo "ERROR: rf100-vl submodule not found or not initialized"
    echo "Run: git submodule update --init --recursive"
    exit 1
fi

# Check for API key
if [ -z "${ROBOFLOW_API_KEY}" ]; then
    echo "WARNING: ROBOFLOW_API_KEY environment variable is not set"
    echo ""
    echo "To get your API key:"
    echo "1. Sign up for a free account at https://universe.roboflow.com/"
    echo "2. Go to your account settings to find your API key"
    echo "3. Export it: export ROBOFLOW_API_KEY=your_key_here"
    echo ""
    echo "Skipping dataset download. You can run this script later with the API key set."
    exit 0
fi

# Default download path
DOWNLOAD_PATH="${1:-./data/roboflow_vl_100}"

echo ""
echo "Download configuration:"
echo "  API Key: ${ROBOFLOW_API_KEY:0:10}... (hidden)"
echo "  Download path: ${DOWNLOAD_PATH}"
echo ""

# Create download directory
mkdir -p "${DOWNLOAD_PATH}"

# Install rf100vl package if not already installed
if ! python -c "import rf100vl" 2>/dev/null; then
    echo "Installing rf100vl package..."
    cd rf100-vl
    pip install -e .
    cd ..
fi

# Download the dataset
echo "Starting download..."
echo "This may take a while depending on your internet connection..."
echo ""

python << EOF
import os
from rf100vl import download_rf100vl

# Set API key
os.environ['ROBOFLOW_API_KEY'] = '${ROBOFLOW_API_KEY}'

# Download dataset
download_rf100vl(path='${DOWNLOAD_PATH}')
print("\n✓ Download completed successfully!")
print(f"Dataset saved to: ${DOWNLOAD_PATH}")
EOF

echo ""
echo "=========================================="
echo "Download completed!"
echo "=========================================="
echo ""
echo "Dataset location: ${DOWNLOAD_PATH}"
echo ""
echo "Next steps:"
echo "1. Verify the dataset structure matches the expected format"
echo "2. Update your config file if needed"
echo "3. Run training with:"
echo "   uv run python -m sam3.train.train -c configs/roboflow_v100/roboflow_v100_full_ft_100_images-copy.yaml --use-cluster 0 --num-gpus 2"
echo ""

exit 0

