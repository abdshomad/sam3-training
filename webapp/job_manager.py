"""Job storage and management."""

import asyncio
import uuid
from datetime import datetime
from pathlib import Path
from typing import Optional

from .models import JobStatus, JobResponse


class JobManager:
    """Manages training jobs: storage, status tracking, and execution."""

    def __init__(self, project_root: Path):
        """Initialize job manager.

        Args:
            project_root: Path to project root directory
        """
        self.project_root = project_root
        self.jobs: dict[str, dict] = {}
        self.running_tasks: dict[str, asyncio.Task] = {}
        self.log_files: dict[str, Path] = {}

    def create_job(
        self,
        dataset_type: str,
        parameters: dict,
        execution_mode: str,
    ) -> str:
        """Create a new job record.

        Args:
            dataset_type: "rf100vl" or "odinw"
            parameters: Training parameters
            execution_mode: "sync" or "async"

        Returns:
            Job ID
        """
        job_id = str(uuid.uuid4())
        self.jobs[job_id] = {
            "job_id": job_id,
            "dataset_type": dataset_type,
            "status": JobStatus.PENDING,
            "created_at": datetime.now(),
            "started_at": None,
            "completed_at": None,
            "parameters": parameters,
            "execution_mode": execution_mode,
            "exit_code": None,
            "error_message": None,
            "log_path": None,
            "logs": [],
        }
        return job_id

    def get_job(self, job_id: str) -> Optional[dict]:
        """Get job by ID.

        Args:
            job_id: Job identifier

        Returns:
            Job dictionary or None if not found
        """
        return self.jobs.get(job_id)

    def get_all_jobs(self, status_filter: Optional[JobStatus] = None) -> list[dict]:
        """Get all jobs, optionally filtered by status.

        Args:
            status_filter: Optional status filter

        Returns:
            List of job dictionaries
        """
        jobs = list(self.jobs.values())
        if status_filter:
            jobs = [j for j in jobs if j["status"] == status_filter]
        return sorted(jobs, key=lambda x: x["created_at"], reverse=True)

    def update_job_status(
        self,
        job_id: str,
        status: JobStatus,
        exit_code: Optional[int] = None,
        error_message: Optional[str] = None,
    ) -> bool:
        """Update job status.

        Args:
            job_id: Job identifier
            status: New status
            exit_code: Optional exit code
            error_message: Optional error message

        Returns:
            True if job was updated, False if not found
        """
        if job_id not in self.jobs:
            return False

        job = self.jobs[job_id]
        job["status"] = status
        if exit_code is not None:
            job["exit_code"] = exit_code
        if error_message:
            job["error_message"] = error_message

        if status == JobStatus.RUNNING and job["started_at"] is None:
            job["started_at"] = datetime.now()
        elif status in (JobStatus.COMPLETED, JobStatus.FAILED, JobStatus.CANCELLED):
            job["completed_at"] = datetime.now()

        return True

    def append_log(self, job_id: str, log_line: str) -> None:
        """Append log line to job logs.

        Args:
            job_id: Job identifier
            log_line: Log line to append
        """
        if job_id in self.jobs:
            self.jobs[job_id]["logs"].append(log_line)
            # Keep only last 10000 lines to prevent memory issues
            if len(self.jobs[job_id]["logs"]) > 10000:
                self.jobs[job_id]["logs"] = self.jobs[job_id]["logs"][-10000:]

    def get_logs(self, job_id: str, tail: Optional[int] = None) -> list[str]:
        """Get job logs.

        Args:
            job_id: Job identifier
            tail: Optional number of lines to return (from end)

        Returns:
            List of log lines
        """
        if job_id not in self.jobs:
            return []
        logs = self.jobs[job_id]["logs"]
        if tail:
            return logs[-tail:]
        return logs

    def set_log_path(self, job_id: str, log_path: Path) -> None:
        """Set log file path for job.

        Args:
            job_id: Job identifier
            log_path: Path to log file
        """
        if job_id in self.jobs:
            self.jobs[job_id]["log_path"] = str(log_path)
            self.log_files[job_id] = log_path

    def cancel_job(self, job_id: str) -> bool:
        """Cancel a running job.

        Args:
            job_id: Job identifier

        Returns:
            True if job was cancelled, False if not found or not running
        """
        if job_id not in self.jobs:
            return False

        job = self.jobs[job_id]
        if job["status"] != JobStatus.RUNNING:
            return False

        # Cancel the running task if it exists
        if job_id in self.running_tasks:
            task = self.running_tasks[job_id]
            task.cancel()
            del self.running_tasks[job_id]

        self.update_job_status(job_id, JobStatus.CANCELLED)
        return True

    def delete_job(self, job_id: str) -> bool:
        """Delete a job record.

        Args:
            job_id: Job identifier

        Returns:
            True if job was deleted, False if not found
        """
        if job_id not in self.jobs:
            return False

        # Cancel if running
        if self.jobs[job_id]["status"] == JobStatus.RUNNING:
            self.cancel_job(job_id)

        # Clean up
        del self.jobs[job_id]
        if job_id in self.running_tasks:
            del self.running_tasks[job_id]
        if job_id in self.log_files:
            del self.log_files[job_id]

        return True

    def register_task(self, job_id: str, task: asyncio.Task) -> None:
        """Register a running task for a job.

        Args:
            job_id: Job identifier
            task: AsyncIO task
        """
        self.running_tasks[job_id] = task

    def get_task(self, job_id: str) -> Optional[asyncio.Task]:
        """Get running task for a job.

        Args:
            job_id: Job identifier

        Returns:
            Task or None
        """
        return self.running_tasks.get(job_id)

