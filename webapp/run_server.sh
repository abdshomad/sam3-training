#!/bin/bash
# Script to run the FastAPI web application

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}"

echo "Starting SAM3 Training Web App..."
echo "Project root: ${PROJECT_ROOT}"
echo "Access the app at: http://localhost:8000"
echo ""

uv run uvicorn webapp.main:app --host 0.0.0.0 --port 8000 --reload

