PLAN

**1.0 - Environment Preparation**
*   **Description:** Setup the necessary Python environment and dependencies required by SAM3 before attempting to run scripts.
*   **Status:** Script Created
*   **Implementation Datetime:** 2025-12-12 21:43:32

**1.1 - Verify Python Environment**
*   **Description:** Add checks to ensure a virtual environment is active (e.g., Conda or venv) to prevent polluting the system Python.
*   **Status:** Script Created
*   **Implementation Datetime:** 2025-12-12 21:43:32

**1.2 - Install SAM3 Dependencies**
*   **Description:** Implement the installation command `pip install -e ".[train]"` inside the `sam3` directory as specified in the "Installation" section. Add a check to skip if already installed.
*   **Status:** Script Created
*   **Implementation Datetime:** 2025-12-12 21:43:32

**2.0 - Data Validation and Configuration**
*   **Description:** Ensure data paths and configuration files exist and are correctly structured before invoking the Python script.
*   **Status:** Script Created
*   **Implementation Datetime:** 2025-12-12 22:06:58

**2.1 - Define Data Root Variables**
*   **Description:** Create variables for `roboflow_vl_100_root` and `odinw_data_root`. Allow these to be passed as environment variables or arguments to the shell script.
*   **Status:** Script Created
*   **Implementation Datetime:** 2025-12-12 22:06:58

**2.2 - Download Roboflow Dataset**
*   **Description:** Download the Roboflow 100-VL dataset using the rf100-vl submodule. Check for API key, install rf100vl package if needed, and download datasets to the specified directory.
*   **Status:** Script Created
*   **Implementation Datetime:** 2025-12-12 22:46:18

**2.3 - Validate Data Directory Structure**
*   **Description:** specific checks for the folder hierarchy mentioned in the README (e.g., verify `AerialMaritimeDrone/large/train` exists for ODinW or `13-lkc01/train` for Roboflow) to prevent runtime errors.
*   **Status:** Script Created
*   **Implementation Datetime:** 2025-12-12 22:06:58

**2.4 - Config File Existence Check**
*   **Description:** Verify that the requested YAML configuration file (passed via `-c`) actually exists in `sam3/train/configs/`.
*   **Status:** Script Created
*   **Implementation Datetime:** 2025-12-12 22:09:29

**3.0 - Script Argument Parsing**
*   **Description:** Create a wrapper interface to handle the various command-line arguments supported by `sam3/train/train.py`.
*   **Status:** Script Created
*   **Implementation Datetime:** 2025-12-12 22:09:29

**3.1 - Implement Mode Selection (Local vs. Cluster)**
*   **Description:** Parse a flag (e.g., `--mode local|cluster`) that maps to the `--use-cluster 0` or `--use-cluster 1` arguments in the python script.
*   **Status:** Script Created
*   **Implementation Datetime:** 2025-12-12 22:09:29

**3.2 - Implement Resource Allocation Flags**
*   **Description:** Add support for parsing `--num-gpus`, `--num-nodes`, `--partition`, `--account`, and `--qos` arguments to pass through to the training script.
*   **Status:** Script Created
*   **Implementation Datetime:** 2025-12-12 22:21:15

**3.3 - Implement Task Type Selection (Train vs. Eval)**
*   **Description:** Allow a simple flag to switch between training configurations (e.g., `roboflow_v100_full_ft_100_images.yaml`) and evaluation configurations (e.g., `roboflow_v100_eval.yaml`).
*   **Status:** Script Created
*   **Implementation Datetime:** 2025-12-12 22:21:15

**4.0 - Execution Logic Construction**
*   **Description:** Dynamically build and execute the final Python command based on the parsed arguments.
*   **Status:** Script Created
*   **Implementation Datetime:** 2025-12-12 22:21:15

**4.1 - Construct Local Training Command**
*   **Description:** detailed logic to build the command: `python sam3/train/train.py -c [CONFIG] --use-cluster 0 --num-gpus [N]` when in local mode.
*   **Status:** Script Created
*   **Implementation Datetime:** 2025-12-12 23:00:03

**4.2 - Construct Cluster Training Command**
*   **Description:** detailed logic to build the command: `python sam3/train/train.py -c [CONFIG] --use-cluster 1 --partition [PARTITION] ...` when in cluster mode.
*   **Status:** Script Created
*   **Implementation Datetime:** 2025-12-12 23:00:03

**4.3 - Job Array Configuration (Optional)**
*   **Description:** Add logic to handle job arrays for dataset sweeps if the config matches `roboflow` or `odinw` specific structures, enabling `submitit.job_array` parameters.
*   **Status:** Script Created
*   **Implementation Datetime:** 2025-12-12 23:00:03

**5.0 - Post-Execution and Monitoring**
*   **Description:** Handle output feedback and monitoring tools setup.
*   **Status:** Script Created
*   **Implementation Datetime:** 2025-12-12 23:15:48

**5.1 - Log Directory Feedback**
*   **Description:** After script launch, parse the output or config to print the location of `experiment_log_dir` so the user knows where `config_resolved.yaml` and checkpoints are saved.
*   **Status:** Script Created
*   **Implementation Datetime:** 2025-12-12 23:15:48

**5.2 - Tensorboard Launch Helper**
*   **Description:** Add a helper function or prompt at the end of the script suggesting the command `tensorboard --logdir [experiment_log_dir]/tensorboard`.
*   **Status:** Script Created
*   **Implementation Datetime:** 2025-12-12 23:15:48