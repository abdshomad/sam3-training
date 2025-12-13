"""Training script execution wrapper."""

import asyncio
import subprocess
from pathlib import Path
from typing import Optional

from .job_manager import JobManager
from .models import JobStatus


class TrainingExecutor:
    """Executes training scripts and captures output."""

    def __init__(self, project_root: Path, job_manager: JobManager):
        """Initialize training executor.

        Args:
            project_root: Path to project root directory
            job_manager: Job manager instance
        """
        self.project_root = project_root
        self.job_manager = job_manager
        self.scripts_dir = project_root / "scripts"

    def build_rf100vl_args(self, params: dict) -> list[str]:
        """Build command-line arguments for RF100VL training script.

        Args:
            params: Training parameters dictionary

        Returns:
            List of command-line arguments
        """
        args = []

        if params.get("supercategory"):
            args.extend(["--supercategory", params["supercategory"]])

        if params.get("mode"):
            args.extend(["--mode", params["mode"]])

        if params.get("num_gpus"):
            args.extend(["--num-gpus", str(params["num_gpus"])])

        if params.get("num_nodes"):
            args.extend(["--num-nodes", str(params["num_nodes"])])

        if params.get("partition"):
            args.extend(["--partition", params["partition"]])

        if params.get("account"):
            args.extend(["--account", params["account"]])

        if params.get("qos"):
            args.extend(["--qos", params["qos"]])

        if params.get("roboflow_root"):
            args.extend(["--roboflow-root", params["roboflow_root"]])

        if params.get("experiment_dir"):
            args.extend(["--experiment-dir", params["experiment_dir"]])

        if params.get("bpe_path"):
            args.extend(["--bpe-path", params["bpe_path"]])

        if params.get("base_config"):
            args.extend(["--base-config", params["base_config"]])

        if params.get("skip_config_resolution", False):
            args.append("--skip-config-resolution")

        if params.get("skip_config_validation", False):
            args.append("--skip-config-validation")

        if params.get("skip_env_setup", False):
            args.append("--skip-env-setup")

        if params.get("skip_data_validation", False):
            args.append("--skip-data-validation")

        if params.get("dry_run", False):
            args.append("--dry-run")

        return args

    def build_odinw_args(self, params: dict) -> list[str]:
        """Build command-line arguments for ODinW training script.

        Args:
            params: Training parameters dictionary

        Returns:
            List of command-line arguments
        """
        args = []

        if params.get("config_type"):
            args.extend(["--config-type", params["config_type"]])

        if params.get("mode"):
            args.extend(["--mode", params["mode"]])

        if params.get("num_gpus"):
            args.extend(["--num-gpus", str(params["num_gpus"])])

        if params.get("num_nodes"):
            args.extend(["--num-nodes", str(params["num_nodes"])])

        if params.get("partition"):
            args.extend(["--partition", params["partition"]])

        if params.get("account"):
            args.extend(["--account", params["account"]])

        if params.get("qos"):
            args.extend(["--qos", params["qos"]])

        if params.get("odinw_root"):
            args.extend(["--odinw-root", params["odinw_root"]])

        if params.get("experiment_dir"):
            args.extend(["--experiment-dir", params["experiment_dir"]])

        if params.get("bpe_path"):
            args.extend(["--bpe-path", params["bpe_path"]])

        if params.get("base_config"):
            args.extend(["--base-config", params["base_config"]])

        if params.get("skip_config_resolution", False):
            args.append("--skip-config-resolution")

        if params.get("skip_config_validation", False):
            args.append("--skip-config-validation")

        if params.get("skip_env_setup", False):
            args.append("--skip-env-setup")

        if params.get("skip_data_validation", False):
            args.append("--skip-data-validation")

        if params.get("dry_run", False):
            args.append("--dry-run")

        return args

    async def execute_training(
        self,
        job_id: str,
        dataset_type: str,
        params: dict,
    ) -> int:
        """Execute training script asynchronously.

        Args:
            job_id: Job identifier
            dataset_type: "rf100vl" or "odinw"
            params: Training parameters

        Returns:
            Exit code
        """
        # Determine script path
        if dataset_type == "rf100vl":
            script_path = self.scripts_dir / "train_rf100vl.sh"
            args = self.build_rf100vl_args(params)
        elif dataset_type == "odinw":
            script_path = self.scripts_dir / "train_odinw.sh"
            args = self.build_odinw_args(params)
        else:
            raise ValueError(f"Unknown dataset type: {dataset_type}")

        if not script_path.exists():
            error_msg = f"Training script not found: {script_path}"
            self.job_manager.append_log(job_id, f"ERROR: {error_msg}")
            self.job_manager.update_job_status(job_id, JobStatus.FAILED, exit_code=1, error_message=error_msg)
            return 1

        # Build command
        cmd = ["bash", str(script_path)] + args

        # Update status
        self.job_manager.update_job_status(job_id, JobStatus.RUNNING)
        self.job_manager.append_log(job_id, f"Executing: {' '.join(cmd)}")
        self.job_manager.append_log(job_id, "=" * 80)

        # Create log file
        log_dir = self.project_root / "experiments" / "logs"
        log_dir.mkdir(parents=True, exist_ok=True)
        from datetime import datetime

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_file = log_dir / f"training_{dataset_type}_{job_id[:8]}_{timestamp}.log"
        self.job_manager.set_log_path(job_id, log_file)

        try:
            # Execute process
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
                cwd=str(self.project_root),
                env=None,  # Use current environment
            )

            # Stream output
            with open(log_file, "w") as f:
                while True:
                    line = await process.stdout.readline()
                    if not line:
                        break

                    line_str = line.decode("utf-8", errors="replace").rstrip()
                    self.job_manager.append_log(job_id, line_str)
                    f.write(line_str + "\n")
                    f.flush()

            # Wait for completion
            exit_code = await process.wait()

            # Update status
            if exit_code == 0:
                self.job_manager.update_job_status(job_id, JobStatus.COMPLETED, exit_code=0)
                self.job_manager.append_log(job_id, "=" * 80)
                self.job_manager.append_log(job_id, "Training completed successfully")
            else:
                error_msg = f"Training failed with exit code {exit_code}"
                self.job_manager.update_job_status(job_id, JobStatus.FAILED, exit_code=exit_code, error_message=error_msg)
                self.job_manager.append_log(job_id, "=" * 80)
                self.job_manager.append_log(job_id, f"ERROR: {error_msg}")

            return exit_code

        except asyncio.CancelledError:
            self.job_manager.append_log(job_id, "=" * 80)
            self.job_manager.append_log(job_id, "Training cancelled by user")
            self.job_manager.update_job_status(job_id, JobStatus.CANCELLED, exit_code=-1)
            raise
        except Exception as e:
            error_msg = f"Execution error: {str(e)}"
            self.job_manager.append_log(job_id, f"ERROR: {error_msg}")
            self.job_manager.update_job_status(job_id, JobStatus.FAILED, exit_code=1, error_message=error_msg)
            return 1

