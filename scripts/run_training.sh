#!/bin/bash
# Master script to execute all training setup and execution steps
# Orchestrates: Environment Setup → Data Validation → Config Validation → 
#               Argument Parsing → Training Execution → Post-Execution Monitoring

set -e

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Change to project root
cd "${PROJECT_ROOT}"

# Initialize variables
CONFIG_ARG=""
MODE="local"
NUM_GPUS=""
NUM_NODES=""
PARTITION=""
ACCOUNT=""
QOS=""
ROBOFLOW_ROOT=""
ODINW_ROOT=""
DATASET_TYPE="both"
SKIP_ENV_SETUP=false
SKIP_DATA_VALIDATION=false
SKIP_CONFIG_VALIDATION=false
TRAINING_OUTPUT_LOG=""
EXECUTE_TRAINING=true

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_ARG="$2"
            shift 2
            ;;
        --mode)
            MODE="$2"
            shift 2
            ;;
        --num-gpus)
            NUM_GPUS="$2"
            shift 2
            ;;
        --num-nodes)
            NUM_NODES="$2"
            shift 2
            ;;
        --partition)
            PARTITION="$2"
            shift 2
            ;;
        --account)
            ACCOUNT="$2"
            shift 2
            ;;
        --qos)
            QOS="$2"
            shift 2
            ;;
        --roboflow-root)
            ROBOFLOW_ROOT="$2"
            shift 2
            ;;
        --odinw-root)
            ODINW_ROOT="$2"
            shift 2
            ;;
        --dataset-type)
            DATASET_TYPE="$2"
            shift 2
            ;;
        --skip-env-setup)
            SKIP_ENV_SETUP=true
            shift
            ;;
        --skip-data-validation)
            SKIP_DATA_VALIDATION=true
            shift
            ;;
        --skip-config-validation)
            SKIP_CONFIG_VALIDATION=true
            shift
            ;;
        --output-log)
            TRAINING_OUTPUT_LOG="$2"
            shift 2
            ;;
        --dry-run)
            EXECUTE_TRAINING=false
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Master orchestration script for SAM3 training setup and execution."
            echo ""
            echo "Required Options:"
            echo "  -c, --config PATH         Training config file path (required)"
            echo "                            Examples:"
            echo "                              configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml"
            echo "                              roboflow_v100/roboflow_v100_full_ft_100_images.yaml"
            echo ""
            echo "Execution Options:"
            echo "  --mode MODE               Execution mode: 'local' or 'cluster' (default: local)"
            echo "  --num-gpus N              Number of GPUs per node"
            echo "  --num-nodes N             Number of nodes for distributed training"
            echo ""
            echo "Cluster Options (for --mode cluster):"
            echo "  --partition NAME          SLURM partition name"
            echo "  --account NAME            SLURM account name"
            echo "  --qos NAME                SLURM QOS setting"
            echo ""
            echo "Data Options:"
            echo "  --roboflow-root PATH      Path to Roboflow VL-100 dataset root"
            echo "  --odinw-root PATH         Path to ODinW dataset root"
            echo "  --dataset-type TYPE       Dataset type to validate: roboflow, odinw, or both (default: both)"
            echo ""
            echo "Control Options:"
            echo "  --skip-env-setup          Skip environment setup step"
            echo "  --skip-data-validation    Skip data validation step"
            echo "  --skip-config-validation  Skip config validation step"
            echo "  --output-log PATH         Path to save training output log (default: auto-generated)"
            echo "  --dry-run                 Construct command but don't execute training"
            echo ""
            echo "Examples:"
            echo "  # Local training with single GPU:"
            echo "  $0 -c configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml --mode local --num-gpus 1"
            echo ""
            echo "  # Cluster training:"
            echo "  $0 -c configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml \\"
            echo "      --mode cluster --num-gpus 8 --num-nodes 2 \\"
            echo "      --partition gpu_partition --account my_account"
            echo ""
            echo "  # With data validation:"
            echo "  $0 -c configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml \\"
            echo "      --roboflow-root /path/to/roboflow --odinw-root /path/to/odinw"
            echo ""
            echo "  -h, --help                Show this help message"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate required config argument
if [ -z "${CONFIG_ARG}" ]; then
    echo "ERROR: Config file path is required"
    echo "Use -c/--config to specify the training configuration file"
    echo "Use --help for more information"
    exit 1
fi

# Normalize mode
MODE="$(echo "${MODE}" | tr '[:upper:]' '[:lower:]')"
if [ "${MODE}" != "local" ] && [ "${MODE}" != "cluster" ]; then
    echo "ERROR: Invalid mode: ${MODE}"
    echo "Mode must be either 'local' or 'cluster'"
    exit 1
fi

# Map mode to use-cluster value
if [ "${MODE}" = "local" ]; then
    USE_CLUSTER="0"
else
    USE_CLUSTER="1"
fi

echo "=========================================="
echo "SAM3 Training Orchestration"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Config: ${CONFIG_ARG}"
echo "  Mode: ${MODE} (--use-cluster ${USE_CLUSTER})"
if [ -n "${NUM_GPUS}" ]; then
    echo "  Num GPUs: ${NUM_GPUS}"
fi
if [ -n "${NUM_NODES}" ]; then
    echo "  Num Nodes: ${NUM_NODES}"
fi
if [ "${MODE}" = "cluster" ]; then
    if [ -n "${PARTITION}" ]; then
        echo "  Partition: ${PARTITION}"
    fi
    if [ -n "${ACCOUNT}" ]; then
        echo "  Account: ${ACCOUNT}"
    fi
    if [ -n "${QOS}" ]; then
        echo "  QOS: ${QOS}"
    fi
fi
echo ""

# Generate output log path if not provided
if [ -z "${TRAINING_OUTPUT_LOG}" ] && [ "${EXECUTE_TRAINING}" = true ]; then
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    CONFIG_BASENAME=$(basename "${CONFIG_ARG}" .yaml)
    TRAINING_OUTPUT_LOG="${PROJECT_ROOT}/experiments/logs/training_${CONFIG_BASENAME}_${TIMESTAMP}.log"
    mkdir -p "$(dirname "${TRAINING_OUTPUT_LOG}")"
fi

# ============================================================================
# Step 1: Environment Setup
# ============================================================================
if [ "${SKIP_ENV_SETUP}" = false ]; then
    echo "=========================================="
    echo "Step 1: Environment Setup"
    echo "=========================================="
    echo ""
    
    "${SCRIPT_DIR}/task_10_environment_preparation.sh"
    if [ $? -ne 0 ]; then
        echo "ERROR: Environment setup failed"
        exit 1
    fi
    
    echo ""
else
    echo "Skipping Step 1: Environment Setup (--skip-env-setup)"
    echo ""
fi

# ============================================================================
# Step 2: Data Validation
# ============================================================================
if [ "${SKIP_DATA_VALIDATION}" = false ]; then
    echo "=========================================="
    echo "Step 2: Data Validation"
    echo "=========================================="
    echo ""
    
    DATA_VALIDATION_ARGS=()
    if [ -n "${ROBOFLOW_ROOT}" ]; then
        DATA_VALIDATION_ARGS+=(--roboflow-root "${ROBOFLOW_ROOT}")
    fi
    if [ -n "${ODINW_ROOT}" ]; then
        DATA_VALIDATION_ARGS+=(--odinw-root "${ODINW_ROOT}")
    fi
    DATA_VALIDATION_ARGS+=(--dataset-type "${DATASET_TYPE}")
    
    # Temporarily disable exit on error for data validation (non-critical)
    set +e
    "${SCRIPT_DIR}/task_20_data_validation_and_configuration.sh" "${DATA_VALIDATION_ARGS[@]}"
    DATA_VALIDATION_EXIT_CODE=$?
    set -e
    
    if [ ${DATA_VALIDATION_EXIT_CODE} -ne 0 ]; then
        echo "WARNING: Data validation failed or skipped (exit code: ${DATA_VALIDATION_EXIT_CODE})"
        echo "This may be expected if datasets are not yet downloaded or paths are incorrect"
        echo "Continuing with training setup..."
    fi
    
    echo ""
else
    echo "Skipping Step 2: Data Validation (--skip-data-validation)"
    echo ""
fi

# ============================================================================
# Step 3: Config Validation
# ============================================================================
if [ "${SKIP_CONFIG_VALIDATION}" = false ]; then
    echo "=========================================="
    echo "Step 3: Config Validation"
    echo "=========================================="
    echo ""
    
    "${SCRIPT_DIR}/task_25_config_file_existence_check.sh" -c "${CONFIG_ARG}"
    if [ $? -ne 0 ]; then
        echo "ERROR: Config validation failed"
        exit 1
    fi
    
    echo ""
else
    echo "Skipping Step 3: Config Validation (--skip-config-validation)"
    echo ""
fi

# ============================================================================
# Step 4: Argument Parsing
# ============================================================================
echo "=========================================="
echo "Step 4: Argument Parsing"
echo "=========================================="
echo ""

ARG_PARSING_ARGS=(-c "${CONFIG_ARG}" --use-cluster "${USE_CLUSTER}")
if [ -n "${NUM_GPUS}" ]; then
    ARG_PARSING_ARGS+=(--num-gpus "${NUM_GPUS}")
fi
if [ -n "${NUM_NODES}" ]; then
    ARG_PARSING_ARGS+=(--num-nodes "${NUM_NODES}")
fi
if [ -n "${PARTITION}" ]; then
    ARG_PARSING_ARGS+=(--partition "${PARTITION}")
fi
if [ -n "${ACCOUNT}" ]; then
    ARG_PARSING_ARGS+=(--account "${ACCOUNT}")
fi
if [ -n "${QOS}" ]; then
    ARG_PARSING_ARGS+=(--qos "${QOS}")
fi

"${SCRIPT_DIR}/task_30_script_argument_parsing.sh" "${ARG_PARSING_ARGS[@]}"
if [ $? -ne 0 ]; then
    echo "ERROR: Argument parsing failed"
    exit 1
fi

echo ""

# ============================================================================
# Step 5: Execute Training
# ============================================================================
echo "=========================================="
echo "Step 5: Training Execution"
echo "=========================================="
echo ""

# Construct training command
EXECUTION_ARGS=(-c "${CONFIG_ARG}" --use-cluster "${USE_CLUSTER}")
if [ -n "${NUM_GPUS}" ]; then
    EXECUTION_ARGS+=(--num-gpus "${NUM_GPUS}")
fi
if [ -n "${NUM_NODES}" ]; then
    EXECUTION_ARGS+=(--num-nodes "${NUM_NODES}")
fi
if [ -n "${PARTITION}" ]; then
    EXECUTION_ARGS+=(--partition "${PARTITION}")
fi
if [ -n "${ACCOUNT}" ]; then
    EXECUTION_ARGS+=(--account "${ACCOUNT}")
fi
if [ -n "${QOS}" ]; then
    EXECUTION_ARGS+=(--qos "${QOS}")
fi

"${SCRIPT_DIR}/task_40_execution_logic_construction.sh" "${EXECUTION_ARGS[@]}"
if [ $? -ne 0 ]; then
    echo "ERROR: Command construction failed"
    exit 1
fi

echo ""

# Check if training command was constructed
if [ -z "${SAM3_TRAIN_COMMAND}" ]; then
    echo "ERROR: Training command was not constructed"
    exit 1
fi

echo "Training command: ${SAM3_TRAIN_COMMAND}"
echo ""

if [ "${EXECUTE_TRAINING}" = false ]; then
    echo "Dry-run mode: Training command constructed but not executed"
    echo "To execute, run:"
    echo "  ${SAM3_TRAIN_COMMAND}"
    echo ""
    exit 0
fi

# Execute training and capture output
echo "Starting training..."
echo "Output will be logged to: ${TRAINING_OUTPUT_LOG}"
echo ""

# Activate virtual environment if it exists
if [ -f "${PROJECT_ROOT}/.venv/bin/activate" ]; then
    source "${PROJECT_ROOT}/.venv/bin/activate"
fi

# Execute training command and capture output
# Use tee to both display and save output
if [ -n "${TRAINING_OUTPUT_LOG}" ]; then
    echo "Training output log: ${TRAINING_OUTPUT_LOG}"
    echo ""
    
    # Execute and tee output
    eval "${SAM3_TRAIN_COMMAND}" 2>&1 | tee "${TRAINING_OUTPUT_LOG}"
    TRAINING_EXIT_CODE=${PIPESTATUS[0]}
else
    # Execute without logging
    eval "${SAM3_TRAIN_COMMAND}"
    TRAINING_EXIT_CODE=$?
fi

echo ""
echo "Training execution completed with exit code: ${TRAINING_EXIT_CODE}"
echo ""

# Export training output log for post-execution
if [ -n "${TRAINING_OUTPUT_LOG}" ]; then
    export SAM3_TRAINING_OUTPUT_LOG="${TRAINING_OUTPUT_LOG}"
fi

# ============================================================================
# Step 6: Post-Execution Monitoring
# ============================================================================
echo "=========================================="
echo "Step 6: Post-Execution Monitoring"
echo "=========================================="
echo ""

POST_EXEC_ARGS=(--config "${CONFIG_ARG}" --mode "${MODE}")
if [ -n "${TRAINING_OUTPUT_LOG}" ] && [ -f "${TRAINING_OUTPUT_LOG}" ]; then
    POST_EXEC_ARGS+=(--input-file "${TRAINING_OUTPUT_LOG}")
fi

"${SCRIPT_DIR}/task_50_post_execution_and_monitoring.sh" "${POST_EXEC_ARGS[@]}" || {
    POST_EXEC_EXIT_CODE=$?
    echo "WARNING: Post-execution monitoring had issues (exit code: ${POST_EXEC_EXIT_CODE})"
    echo "This is non-fatal - training may have completed successfully"
}

echo ""

# ============================================================================
# Summary
# ============================================================================
echo "=========================================="
echo "Training Orchestration Complete"
echo "=========================================="
echo ""

if [ ${TRAINING_EXIT_CODE} -eq 0 ]; then
    echo "✓ Training completed successfully"
else
    echo "⚠ Training completed with exit code: ${TRAINING_EXIT_CODE}"
fi

if [ -n "${TRAINING_OUTPUT_LOG}" ]; then
    echo "  Training log: ${TRAINING_OUTPUT_LOG}"
fi

if [ -n "${SAM3_EXPERIMENT_LOG_DIR}" ]; then
    echo "  Experiment log directory: ${SAM3_EXPERIMENT_LOG_DIR}"
fi

echo ""
echo "Next steps:"
echo "  1. Monitor training progress with TensorBoard (see above)"
if [ -n "${SAM3_EXPERIMENT_LOG_DIR}" ]; then
    echo "  2. Check checkpoints in: ${SAM3_EXPERIMENT_LOG_DIR}/checkpoints/"
    echo "  3. Review resolved config: ${SAM3_EXPERIMENT_LOG_DIR}/config_resolved.yaml"
fi
echo ""

# Exit with training exit code
exit ${TRAINING_EXIT_CODE}

