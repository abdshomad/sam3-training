#!/bin/bash
# Restart script for SAM3 Training Web App
# Stops and starts the app

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"

cd "${PROJECT_ROOT}"

# Load environment variables from .env file if it exists
if [ -f "${PROJECT_ROOT}/.env" ]; then
    set -a  # Automatically export all variables
    source "${PROJECT_ROOT}/.env"
    set +a  # Turn off automatic export
fi

echo "=========================================="
echo "Restarting SAM3 Training Web App"
echo "=========================================="
echo ""

# Stop if running
if [ -f "${PROJECT_ROOT}/webapp/webapp.pid" ]; then
    echo "Stopping existing instance..."
    "${SCRIPT_DIR}/stop.sh"
    echo ""
    sleep 2
fi

# Start
echo "Starting new instance..."
"${SCRIPT_DIR}/start.sh"

