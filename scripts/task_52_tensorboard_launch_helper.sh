#!/bin/bash
# Task ID: 5.2
# Description: TensorBoard Launch Helper
# Created: 2025-12-13

set -e

echo "=========================================="
echo "Task 5.2: TensorBoard Launch Helper"
echo "=========================================="

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Change to project root
cd "${PROJECT_ROOT}"

EXPERIMENT_LOG_DIR=""
TENSORBOARD_PORT="6006"
LAUNCH_TENSORBOARD=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --log-dir)
            EXPERIMENT_LOG_DIR="$2"
            shift 2
            ;;
        --port|-p)
            TENSORBOARD_PORT="$2"
            shift 2
            ;;
        --launch|-l)
            LAUNCH_TENSORBOARD=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Provides TensorBoard monitoring command suggestion and optionally launches it."
            echo ""
            echo "Options:"
            echo "  --log-dir PATH           Experiment log directory (required if not in env)"
            echo "  --port PORT, -p          TensorBoard port (default: 6006)"
            echo "  --launch, -l             Launch TensorBoard automatically"
            echo ""
            echo "Environment Variables:"
            echo "  SAM3_EXPERIMENT_LOG_DIR  Experiment log directory"
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

# Get log directory from argument or environment
if [ -z "${EXPERIMENT_LOG_DIR}" ] && [ -n "${SAM3_EXPERIMENT_LOG_DIR}" ]; then
    EXPERIMENT_LOG_DIR="${SAM3_EXPERIMENT_LOG_DIR}"
fi

# Validate log directory is provided
if [ -z "${EXPERIMENT_LOG_DIR}" ]; then
    echo "WARNING: Experiment log directory not provided"
    echo ""
    echo "Please provide one of:"
    echo "  --log-dir PATH           Direct path to log directory"
    echo "  SAM3_EXPERIMENT_LOG_DIR  Environment variable"
    echo ""
    echo "Or run task_51_log_directory_feedback.sh first to extract it."
    echo ""
    echo "This script requires arguments to function. Exiting gracefully."
    exit 0
fi

# Convert to absolute path if relative
if [[ ! "${EXPERIMENT_LOG_DIR}" =~ ^/ ]]; then
    EXPERIMENT_LOG_DIR="$(cd "$(dirname "${EXPERIMENT_LOG_DIR}")" && pwd)/$(basename "${EXPERIMENT_LOG_DIR}")"
fi

# Construct TensorBoard log directory path
TENSORBOARD_LOG_DIR="${EXPERIMENT_LOG_DIR}/tensorboard"

echo ""
echo "TensorBoard Configuration:"
echo "  Experiment Log Dir: ${EXPERIMENT_LOG_DIR}"
echo "  TensorBoard Log Dir: ${TENSORBOARD_LOG_DIR}"
echo "  Port: ${TENSORBOARD_PORT}"
echo ""

# Check if TensorBoard is installed
TENSORBOARD_CMD=""
if command -v tensorboard &> /dev/null; then
    TENSORBOARD_CMD="tensorboard"
    echo "✓ TensorBoard command found: $(which tensorboard)"
elif python3 -m tensorboard --version &> /dev/null 2>&1; then
    TENSORBOARD_CMD="python3 -m tensorboard"
    echo "✓ TensorBoard module found (via python3 -m tensorboard)"
elif python -m tensorboard --version &> /dev/null 2>&1; then
    TENSORBOARD_CMD="python -m tensorboard"
    echo "✓ TensorBoard module found (via python -m tensorboard)"
else
    echo "⚠ WARNING: TensorBoard not found in PATH or as Python module"
    echo ""
    echo "To install TensorBoard, run:"
    echo "  uv sync  # Install all dependencies from pyproject.toml (includes tensorboard)"
    echo "  # or if already synced, install via:"
    echo "  uv pip install tensorboard"
    echo ""
    TENSORBOARD_CMD="tensorboard"  # Still show the command, user can install later
fi

# Check if tensorboard directory exists
if [ ! -d "${TENSORBOARD_LOG_DIR}" ]; then
    echo "⚠ WARNING: TensorBoard log directory does not exist yet:"
    echo "  ${TENSORBOARD_LOG_DIR}"
    echo ""
    echo "This is normal if training hasn't started yet. TensorBoard will"
    echo "automatically create this directory when training begins."
    echo ""
else
    echo "✓ TensorBoard log directory exists"
    
    # Count event files if any
    EVENT_COUNT=$(find "${TENSORBOARD_LOG_DIR}" -name "events.out.tfevents.*" 2>/dev/null | wc -l)
    if [ "${EVENT_COUNT}" -gt 0 ]; then
        echo "  Found ${EVENT_COUNT} event file(s)"
    else
        echo "  No event files yet (training may not have started)"
    fi
    echo ""
fi

# Construct the TensorBoard command
TB_CMD="${TENSORBOARD_CMD} --logdir ${TENSORBOARD_LOG_DIR} --port ${TENSORBOARD_PORT}"

echo "=========================================="
echo "TensorBoard Command"
echo "=========================================="
echo ""
echo "To monitor training progress, run:"
echo ""
echo "  ${TB_CMD}"
echo ""
echo "Then open your browser to:"
echo "  http://localhost:${TENSORBOARD_PORT}"
echo ""

# Optionally launch TensorBoard
if [ "${LAUNCH_TENSORBOARD}" = true ]; then
    # Extract first word from TENSORBOARD_CMD for command -v check
    TB_CMD_FIRST=$(echo "${TENSORBOARD_CMD}" | awk '{print $1}')
    if [ -z "${TENSORBOARD_CMD}" ] || ! command -v "${TB_CMD_FIRST}" &> /dev/null; then
        if ! python3 -m tensorboard --version &> /dev/null 2>&1 && ! python -m tensorboard --version &> /dev/null 2>&1; then
            echo "ERROR: Cannot launch TensorBoard - not installed"
            echo "Please install TensorBoard first:"
            echo "  uv sync  # Install all dependencies from pyproject.toml (includes tensorboard)"
            exit 1
        fi
    fi
    
    echo "Launching TensorBoard..."
    echo ""
    
    # Check if port is already in use
    if command -v lsof &> /dev/null; then
        if lsof -Pi :"${TENSORBOARD_PORT}" -sTCP:LISTEN -t >/dev/null 2>&1; then
            echo "⚠ WARNING: Port ${TENSORBOARD_PORT} is already in use"
            echo "TensorBoard may fail to start. Consider using a different port with --port"
            echo ""
        fi
    fi
    
    # Launch TensorBoard in background
    echo "TensorBoard is starting..."
    echo "Access it at: http://localhost:${TENSORBOARD_PORT}"
    echo ""
    echo "Press Ctrl+C to stop TensorBoard"
    echo ""
    
    # Execute TensorBoard (foreground, so user can see output and Ctrl+C to stop)
    exec ${TB_CMD}
else
    echo "Tip: Use --launch flag to automatically start TensorBoard"
    echo ""
fi

exit 0

