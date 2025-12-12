#!/bin/bash
# Task ID: 1.1
# Description: Verify Python Environment
# Created: 2025-12-12 21:43:32

set -e

echo "=========================================="
echo "Task 1.1: Verify Python Environment"
echo "=========================================="

# Check if virtual environment is active
if [ -z "${VIRTUAL_ENV}" ] && [ -z "${CONDA_DEFAULT_ENV}" ]; then
    # Check if we're in a venv by checking if .venv exists and is activated
    if [ ! -f ".venv/bin/activate" ]; then
        echo "ERROR: No virtual environment detected!"
        echo ""
        echo "Please activate a virtual environment before running this script:"
        echo "  - For uv venv: source .venv/bin/activate"
        echo "  - For conda: conda activate <env_name>"
        echo ""
        exit 1
    fi
else
    echo "✓ Virtual environment detected:"
    if [ -n "${VIRTUAL_ENV}" ]; then
        echo "  VIRTUAL_ENV: ${VIRTUAL_ENV}"
    fi
    if [ -n "${CONDA_DEFAULT_ENV}" ]; then
        echo "  CONDA_DEFAULT_ENV: ${CONDA_DEFAULT_ENV}"
    fi
fi

# Verify Python is available
if ! command -v python &> /dev/null; then
    echo "ERROR: Python not found in PATH"
    exit 1
fi

echo "✓ Python found: $(which python)"
echo "✓ Python version: $(python --version)"
echo ""
echo "Python environment verification completed successfully."
echo ""

