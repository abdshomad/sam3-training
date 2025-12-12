#!/bin/bash
# Task ID: 1.0
# Description: Environment Preparation
# Created: 2025-12-12 21:43:32

set -e

echo "=========================================="
echo "Task 1.0: Environment Preparation"
echo "=========================================="

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Change to project root
cd "${PROJECT_ROOT}"

echo "Project root: ${PROJECT_ROOT}"
echo ""

# Step 1: Setup virtual environment using uv
echo "Step 1: Setting up virtual environment..."
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment using uv..."
    if ! command -v uv &> /dev/null; then
        echo "ERROR: uv not found. Please install uv first."
        echo "Installation: curl -LsSf https://astral.sh/uv/install.sh | sh"
        exit 1
    fi
    uv venv
    echo "✓ Virtual environment created"
else
    echo "✓ Virtual environment already exists"
fi

# Activate virtual environment
if [ -f ".venv/bin/activate" ]; then
    echo "Activating virtual environment..."
    source .venv/bin/activate
    echo "✓ Virtual environment activated"
else
    echo "ERROR: Failed to activate virtual environment"
    exit 1
fi

echo ""

# Step 2: Verify Python environment (Task 1.1)
echo "Step 2: Verifying Python environment..."
"${SCRIPT_DIR}/task_11_verify_python_environment.sh"
if [ $? -ne 0 ]; then
    echo "ERROR: Python environment verification failed"
    exit 1
fi

# Step 3: Install SAM3 dependencies (Task 1.2)
echo "Step 3: Installing SAM3 dependencies..."
"${SCRIPT_DIR}/task_12_install_sam3_dependencies.sh"
if [ $? -ne 0 ]; then
    echo "ERROR: SAM3 dependencies installation failed"
    exit 1
fi

echo "=========================================="
echo "Environment preparation completed successfully!"
echo "=========================================="
echo ""

