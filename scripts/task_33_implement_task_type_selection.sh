#!/bin/bash
# Task ID: 3.3
# Description: Implement Task Type Selection (Train vs. Eval)
# Created: 2025-12-12

set -e

echo "=========================================="
echo "Task 3.3: Implement Task Type Selection"
echo "=========================================="

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Change to project root
cd "${PROJECT_ROOT}"

# Initialize variables
TASK_TYPE=""
CONFIG_ARG=""
CONFIG_SUGGESTION=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --task-type)
            TASK_TYPE="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_ARG="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --task-type TYPE          Task type: 'train' or 'eval'"
            echo "                            - 'train': Training configurations"
            echo "                            - 'eval': Evaluation configurations"
            echo ""
            echo "  -c, --config PATH         Explicit config file path (overrides task-type suggestion)"
            echo "                            Examples:"
            echo "                              roboflow_v100/roboflow_v100_full_ft_100_images.yaml"
            echo "                              roboflow_v100/roboflow_v100_eval.yaml"
            echo "                              odinw13/odinw_text_only_train.yaml"
            echo ""
            echo "  -h, --help                Show this help message"
            echo ""
            echo "This script helps select between training and evaluation configurations."
            echo "If --task-type is provided, it suggests appropriate config files."
            echo "If --config is provided, it overrides the task-type suggestion."
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate task-type if provided
if [ -n "${TASK_TYPE}" ]; then
    # Normalize to lowercase
    TASK_TYPE="$(echo "${TASK_TYPE}" | tr '[:upper:]' '[:lower:]')"
    
    if [ "${TASK_TYPE}" != "train" ] && [ "${TASK_TYPE}" != "eval" ]; then
        echo "ERROR: Invalid task-type: ${TASK_TYPE}"
        echo "Task-type must be either 'train' or 'eval'"
        exit 1
    fi
fi

# If config is explicitly provided, use it and determine task type from filename
if [ -n "${CONFIG_ARG}" ]; then
    CONFIG_FILE="${CONFIG_ARG}"
    echo "Using explicit config: ${CONFIG_FILE}"
    
    # Try to infer task type from config filename if not provided
    if [ -z "${TASK_TYPE}" ]; then
        if [[ "${CONFIG_FILE}" == *"_eval.yaml" ]] || \
           [[ "${CONFIG_FILE}" == *"gold_image_evals/"* ]] || \
           [[ "${CONFIG_FILE}" == *"silver_image_evals/"* ]] || \
           [[ "${CONFIG_FILE}" == *"saco_video_evals/"* ]]; then
            TASK_TYPE="eval"
            echo "Inferred task type: eval (from config filename)"
        elif [[ "${CONFIG_FILE}" == *"_full_ft_"* ]] || \
             [[ "${CONFIG_FILE}" == *"_train.yaml" ]]; then
            TASK_TYPE="train"
            echo "Inferred task type: train (from config filename)"
        else
            echo "WARNING: Could not infer task type from config filename"
            echo "Please specify --task-type explicitly if needed"
        fi
    fi
elif [ -n "${TASK_TYPE}" ]; then
    # Suggest config files based on task type
    CONFIGS_DIR="${PROJECT_ROOT}/sam3/sam3/train/configs"
    
    if [ ! -d "${CONFIGS_DIR}" ]; then
        echo "WARNING: Configs directory not found: ${CONFIGS_DIR}"
        echo "Cannot suggest config files"
    else
        echo ""
        echo "Suggested config files for task type '${TASK_TYPE}':"
        echo ""
        
        if [ "${TASK_TYPE}" = "train" ]; then
            echo "Training configurations:"
            # Find training configs
            if [ -f "${CONFIGS_DIR}/roboflow_v100/roboflow_v100_full_ft_100_images.yaml" ]; then
                echo "  - roboflow_v100/roboflow_v100_full_ft_100_images.yaml"
                CONFIG_SUGGESTION="roboflow_v100/roboflow_v100_full_ft_100_images.yaml"
            fi
            if [ -d "${CONFIGS_DIR}/odinw13" ]; then
                for config in "${CONFIGS_DIR}/odinw13"/*_train.yaml; do
                    if [ -f "${config}" ]; then
                        config_name=$(basename "${config}")
                        echo "  - odinw13/${config_name}"
                        if [ -z "${CONFIG_SUGGESTION}" ]; then
                            CONFIG_SUGGESTION="odinw13/${config_name}"
                        fi
                    fi
                done
            fi
        else
            echo "Evaluation configurations:"
            # Find eval configs
            if [ -f "${CONFIGS_DIR}/roboflow_v100/roboflow_v100_eval.yaml" ]; then
                echo "  - roboflow_v100/roboflow_v100_eval.yaml"
                CONFIG_SUGGESTION="roboflow_v100/roboflow_v100_eval.yaml"
            fi
            if [ -d "${CONFIGS_DIR}/gold_image_evals" ]; then
                echo "  - gold_image_evals/*.yaml (multiple available)"
            fi
            if [ -d "${CONFIGS_DIR}/silver_image_evals" ]; then
                echo "  - silver_image_evals/*.yaml (multiple available)"
            fi
            if [ -d "${CONFIGS_DIR}/saco_video_evals" ]; then
                echo "  - saco_video_evals/*.yaml (multiple available)"
            fi
        fi
        
        echo ""
        echo "Use -c/--config to specify the exact config file to use"
    fi
else
    echo "WARNING: Neither --task-type nor --config specified"
    echo "Please specify either:"
    echo "  --task-type train|eval  (to get suggestions)"
    echo "  -c/--config PATH       (to specify exact config)"
fi

echo ""
echo "Task type selection summary:"
if [ -n "${TASK_TYPE}" ]; then
    echo "  Task Type: ${TASK_TYPE}"
else
    echo "  Task Type: Not specified"
fi
if [ -n "${CONFIG_ARG}" ]; then
    echo "  Config: ${CONFIG_ARG} (explicit)"
elif [ -n "${CONFIG_SUGGESTION}" ]; then
    echo "  Config Suggestion: ${CONFIG_SUGGESTION}"
else
    echo "  Config: Not specified"
fi
echo ""

# Export variables for use by subsequent scripts
if [ -n "${TASK_TYPE}" ]; then
    export SAM3_TASK_TYPE="${TASK_TYPE}"
fi
if [ -n "${CONFIG_ARG}" ]; then
    export SAM3_CONFIG_ARG="${CONFIG_ARG}"
elif [ -n "${CONFIG_SUGGESTION}" ]; then
    export SAM3_CONFIG_SUGGESTION="${CONFIG_SUGGESTION}"
fi

echo "Task type selection completed successfully!"
echo ""

exit 0

