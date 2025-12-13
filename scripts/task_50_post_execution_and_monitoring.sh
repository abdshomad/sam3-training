#!/bin/bash
# Task ID: 5.0
# Description: Post-Execution and Monitoring
# Created: 2025-12-13

set -e

echo "=========================================="
echo "Task 5.0: Post-Execution and Monitoring"
echo "=========================================="

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

INPUT_FILE=""
CONFIG_ARG=""
EXECUTION_MODE="auto"  # auto, local, cluster
SKIP_TENSORBOARD=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --input-file|-i)
            INPUT_FILE="$2"
            shift 2
            ;;
        --config|-c)
            CONFIG_ARG="$2"
            shift 2
            ;;
        --mode)
            EXECUTION_MODE="$2"
            shift 2
            ;;
        --skip-tensorboard)
            SKIP_TENSORBOARD=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Main coordinator for post-execution monitoring tasks."
            echo "Extracts experiment log directory and provides monitoring guidance."
            echo ""
            echo "Options:"
            echo "  --input-file PATH, -i    Parse log directory from training output file"
            echo "  --config PATH, -c        Extract log directory from config file"
            echo "  --mode MODE              Execution mode: auto, local, or cluster (default: auto)"
            echo "  --skip-tensorboard      Skip TensorBoard helper suggestion"
            echo ""
            echo "Environment Variables:"
            echo "  SAM3_TRAIN_COMMAND      Training command (for reference)"
            echo "  SAM3_CONFIG_ARG          Config file path"
            echo "  SAM3_USE_CLUSTER         Cluster mode (0: local, 1: cluster)"
            echo ""
            echo "Examples:"
            echo "  # From training output file:"
            echo "  $0 --input-file training_output.log"
            echo ""
            echo "  # From config file:"
            echo "  $0 --config configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml"
            echo ""
            echo "  # From stdin (pipe training output):"
            echo "  python -m sam3.train.train -c configs/... | tee training.log | $0 --input-file -"
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

# Determine execution mode if auto
if [ "${EXECUTION_MODE}" = "auto" ]; then
    if [ -n "${SAM3_USE_CLUSTER}" ] && [ "${SAM3_USE_CLUSTER}" = "1" ]; then
        EXECUTION_MODE="cluster"
    else
        EXECUTION_MODE="local"
    fi
fi

echo "Execution mode: ${EXECUTION_MODE}"
echo ""

# Get config from environment if not provided
if [ -z "${CONFIG_ARG}" ] && [ -n "${SAM3_CONFIG_ARG}" ]; then
    CONFIG_ARG="${SAM3_CONFIG_ARG}"
fi

# Step 1: Extract experiment log directory using task 5.1
echo "Step 1: Extracting experiment log directory..."
echo ""

LOG_DIR_EXTRACTED=false
TEMP_OUTPUT_FILE=$(mktemp)

if [ -n "${INPUT_FILE}" ]; then
    # Parse from input file
    if [ "${INPUT_FILE}" = "-" ]; then
        # Read from stdin
        TEMP_FILE=$(mktemp)
        cat > "${TEMP_FILE}"
        "${SCRIPT_DIR}/task_51_log_directory_feedback.sh" --input-file "${TEMP_FILE}" 2>&1 | tee "${TEMP_OUTPUT_FILE}" || true
        rm -f "${TEMP_FILE}"
    else
        "${SCRIPT_DIR}/task_51_log_directory_feedback.sh" --input-file "${INPUT_FILE}" 2>&1 | tee "${TEMP_OUTPUT_FILE}" || true
    fi
    LOG_DIR_EXTRACTED=true
elif [ -n "${CONFIG_ARG}" ]; then
    # Extract from config file
    "${SCRIPT_DIR}/task_51_log_directory_feedback.sh" --config "${CONFIG_ARG}" 2>&1 | tee "${TEMP_OUTPUT_FILE}" || true
    LOG_DIR_EXTRACTED=true
elif [ -n "${SAM3_EXPERIMENT_LOG_DIR}" ]; then
    # Use existing environment variable
    echo "Using existing SAM3_EXPERIMENT_LOG_DIR: ${SAM3_EXPERIMENT_LOG_DIR}"
    LOG_DIR_EXTRACTED=true
else
    echo "⚠ WARNING: No input source provided for log directory extraction"
    echo ""
    echo "Please provide one of:"
    echo "  --input-file PATH    Training output file to parse"
    echo "  --config PATH        Config file to extract from"
    echo ""
    echo "Or ensure SAM3_EXPERIMENT_LOG_DIR is set in environment."
    echo ""
fi

# Extract log directory from task 5.1 output if not already set
if [ -z "${SAM3_EXPERIMENT_LOG_DIR}" ] && [ -f "${TEMP_OUTPUT_FILE}" ]; then
    # Parse "Experiment Log Directory:" line from output
    EXTRACTED_DIR=$(grep -A 1 "Experiment Log Directory:" "${TEMP_OUTPUT_FILE}" | tail -n 1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -n "${EXTRACTED_DIR}" ] && [ -d "${EXTRACTED_DIR}" ]; then
        export SAM3_EXPERIMENT_LOG_DIR="${EXTRACTED_DIR}"
        echo "✓ Captured log directory from task 5.1 output: ${SAM3_EXPERIMENT_LOG_DIR}"
        echo ""
    fi
fi

rm -f "${TEMP_OUTPUT_FILE}"

# Check if log directory was successfully extracted
if [ -z "${SAM3_EXPERIMENT_LOG_DIR}" ]; then
    echo "⚠ WARNING: Could not determine experiment log directory"
    echo ""
    echo "For cluster jobs, the log directory may not be available until the job starts."
    echo "You can check the SLURM output files or wait for the job to begin."
    echo ""
    
    if [ "${EXECUTION_MODE}" = "cluster" ]; then
        echo "For cluster jobs, monitor with:"
        echo "  squeue -u \$USER"
        echo ""
        echo "Once the job starts, check the SLURM output for the log directory location."
        echo ""
    fi
else
    echo "✓ Experiment log directory extracted: ${SAM3_EXPERIMENT_LOG_DIR}"
    echo ""
fi

# Step 2: Provide TensorBoard helper (unless skipped)
if [ "${SKIP_TENSORBOARD}" = false ]; then
    echo "Step 2: TensorBoard monitoring helper..."
    echo ""
    
    if [ -n "${SAM3_EXPERIMENT_LOG_DIR}" ]; then
        "${SCRIPT_DIR}/task_52_tensorboard_launch_helper.sh" --log-dir "${SAM3_EXPERIMENT_LOG_DIR}" || true
    else
        echo "⚠ Skipping TensorBoard helper - log directory not available"
        echo ""
        echo "Once you have the log directory, run:"
        echo "  ${SCRIPT_DIR}/task_52_tensorboard_launch_helper.sh --log-dir <log_dir>"
        echo ""
    fi
else
    echo "Step 2: TensorBoard helper skipped (--skip-tensorboard flag)"
    echo ""
fi

# Step 3: Summary and next steps
echo "=========================================="
echo "Post-Execution Summary"
echo "=========================================="
echo ""

if [ -n "${SAM3_EXPERIMENT_LOG_DIR}" ]; then
    echo "✓ Experiment log directory: ${SAM3_EXPERIMENT_LOG_DIR}"
    echo ""
    echo "Key locations:"
    echo "  - Config: ${SAM3_EXPERIMENT_LOG_DIR}/config_resolved.yaml"
    echo "  - Checkpoints: ${SAM3_EXPERIMENT_LOG_DIR}/checkpoints/"
    echo "  - TensorBoard logs: ${SAM3_EXPERIMENT_LOG_DIR}/tensorboard/"
    echo "  - Text logs: ${SAM3_EXPERIMENT_LOG_DIR}/logs/"
    if [ "${EXECUTION_MODE}" = "cluster" ]; then
        echo "  - SLURM logs: ${SAM3_EXPERIMENT_LOG_DIR}/submitit_logs/"
    fi
    echo ""
else
    echo "⚠ Experiment log directory not yet available"
    echo ""
fi

# Provide mode-specific guidance
if [ "${EXECUTION_MODE}" = "cluster" ]; then
    echo "Cluster execution mode detected:"
    echo "  - Monitor job status: squeue -u \$USER"
    echo "  - View job output: Check SLURM output files in submitit_logs/"
    echo "  - Cancel job if needed: scancel <job_id>"
    echo ""
elif [ "${EXECUTION_MODE}" = "local" ]; then
    echo "Local execution mode detected:"
    echo "  - Training is running in the foreground"
    echo "  - Check the terminal output for progress"
    echo "  - Use Ctrl+C to stop training (may cause checkpoint corruption)"
    echo ""
fi

echo "Next steps:"
echo "  1. Monitor training progress with TensorBoard (see above)"
echo "  2. Check log files in: ${SAM3_EXPERIMENT_LOG_DIR:-<log_dir>}/logs/"
echo "  3. Review resolved config: ${SAM3_EXPERIMENT_LOG_DIR:-<log_dir>}/config_resolved.yaml"
echo ""

# Export for downstream use
if [ -n "${SAM3_EXPERIMENT_LOG_DIR}" ]; then
    export SAM3_EXPERIMENT_LOG_DIR
    echo "✓ SAM3_EXPERIMENT_LOG_DIR exported for downstream scripts"
    echo ""
fi

echo "Post-execution monitoring setup completed!"
echo ""

exit 0

