#!/bin/bash
# Task ID: 6.4
# Description: ODinW Config Path Resolution Script
# Created: 2025-12-13
#
# Wrapper script for task_64_odinw_config_path_resolution.py

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

# Load ODinW specific environment variables from .env.odinw if it exists
if [ -f "${PROJECT_ROOT}/.env.odinw" ]; then
    set -a  # Automatically export all variables
    source "${PROJECT_ROOT}/.env.odinw"
    set +a  # Turn off automatic export
fi

# Execute the Python script with uv run, passing through all arguments
uv run python "${SCRIPT_DIR}/task_64_odinw_config_path_resolution.py" "$@"

