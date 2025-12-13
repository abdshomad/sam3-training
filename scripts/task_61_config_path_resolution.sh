#!/bin/bash
# Task ID: 6.1
# Description: Config Path Resolution Script
# Created: 2025-12-13
#
# Wrapper script for task_61_config_path_resolution.py

set -e

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

# Load RF100-VL specific environment variables from .env.rf100vl if it exists
if [ -f "${PROJECT_ROOT}/.env.rf100vl" ]; then
    set -a  # Automatically export all variables
    source "${PROJECT_ROOT}/.env.rf100vl"
    set +a  # Turn off automatic export
fi

# Execute the Python script with uv run, passing through all arguments
uv run python "${SCRIPT_DIR}/task_61_config_path_resolution.py" "$@"

