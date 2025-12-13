"""API route handlers."""

import asyncio
from pathlib import Path

from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.responses import JSONResponse

from .job_manager import JobManager
from .models import (
    ExecutionMode,
    JobListResponse,
    JobResponse,
    JobStatus,
    JobStatusResponse,
    ODinWTrainingRequest,
    RF100VLTrainingRequest,
)
from .training_executor import TrainingExecutor


def create_routes(job_manager: JobManager, training_executor: TrainingExecutor) -> APIRouter:
    """Create and configure API routes.

    Args:
        job_manager: Job manager instance
        training_executor: Training executor instance

    Returns:
        Configured router
    """
    router = APIRouter()

    @router.post("/api/train/rf100vl", response_model=JobResponse)
    async def submit_rf100vl_job(request: RF100VLTrainingRequest) -> JobResponse:
        """Submit a RF100VL training job.

        Args:
            request: Training request parameters

        Returns:
            Job information
        """
        # Convert request to dict
        params = request.model_dump(exclude={"execution_mode"})
        # Convert enum to string
        if "mode" in params:
            params["mode"] = params["mode"].value
        execution_mode = request.execution_mode

        # Create job
        job_id = job_manager.create_job("rf100vl", params, execution_mode.value)

        # Execute based on mode
        if execution_mode == ExecutionMode.ASYNC:
            # Start background task
            task = asyncio.create_task(training_executor.execute_training(job_id, "rf100vl", params))
            job_manager.register_task(job_id, task)
        else:
            # Execute synchronously
            exit_code = await training_executor.execute_training(job_id, "rf100vl", params)

        # Get job and return
        job = job_manager.get_job(job_id)
        return JobResponse(**job)

    @router.post("/api/train/odinw", response_model=JobResponse)
    async def submit_odinw_job(request: ODinWTrainingRequest) -> JobResponse:
        """Submit an ODinW training job.

        Args:
            request: Training request parameters

        Returns:
            Job information
        """
        # Convert request to dict
        params = request.model_dump(exclude={"execution_mode"})
        # Convert enum to string
        if "config_type" in params:
            params["config_type"] = params["config_type"].value
        if "mode" in params:
            params["mode"] = params["mode"].value
        execution_mode = request.execution_mode

        # Create job
        job_id = job_manager.create_job("odinw", params, execution_mode.value)

        # Execute based on mode
        if execution_mode == ExecutionMode.ASYNC:
            # Start background task
            task = asyncio.create_task(training_executor.execute_training(job_id, "odinw", params))
            job_manager.register_task(job_id, task)
        else:
            # Execute synchronously
            exit_code = await training_executor.execute_training(job_id, "odinw", params)

        # Get job and return
        job = job_manager.get_job(job_id)
        return JobResponse(**job)

    @router.get("/api/jobs", response_model=JobListResponse)
    async def list_jobs(status: JobStatus | None = None) -> JobListResponse:
        """List all jobs, optionally filtered by status.

        Args:
            status: Optional status filter

        Returns:
            List of jobs
        """
        jobs = job_manager.get_all_jobs(status)
        job_responses = [JobResponse(**job) for job in jobs]
        return JobListResponse(jobs=job_responses, total=len(job_responses))

    @router.get("/api/jobs/{job_id}", response_model=JobResponse)
    async def get_job(job_id: str) -> JobResponse:
        """Get job details.

        Args:
            job_id: Job identifier

        Returns:
            Job information

        Raises:
            HTTPException: If job not found
        """
        job = job_manager.get_job(job_id)
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        return JobResponse(**job)

    @router.get("/api/jobs/{job_id}/status", response_model=JobStatusResponse)
    async def get_job_status(job_id: str) -> JobStatusResponse:
        """Get job status.

        Args:
            job_id: Job identifier

        Returns:
            Job status

        Raises:
            HTTPException: If job not found
        """
        job = job_manager.get_job(job_id)
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        return JobStatusResponse(
            job_id=job_id,
            status=job["status"],
            exit_code=job.get("exit_code"),
            error_message=job.get("error_message"),
        )

    @router.websocket("/api/jobs/{job_id}/logs")
    async def stream_logs(websocket: WebSocket, job_id: str):
        """Stream job logs via WebSocket.

        Args:
            websocket: WebSocket connection
            job_id: Job identifier
        """
        await websocket.accept()

        # Check if job exists
        job = job_manager.get_job(job_id)
        if not job:
            await websocket.send_json({"error": "Job not found"})
            await websocket.close()
            return

        # Send existing logs
        existing_logs = job_manager.get_logs(job_id)
        for log_line in existing_logs:
            try:
                await websocket.send_text(log_line)
            except WebSocketDisconnect:
                return

        # Monitor for new logs
        last_log_count = len(existing_logs)
        try:
            while True:
                await asyncio.sleep(0.5)  # Poll every 500ms

                # Check if job is still running
                job = job_manager.get_job(job_id)
                if not job:
                    break

                # Send new logs
                current_logs = job_manager.get_logs(job_id)
                if len(current_logs) > last_log_count:
                    for log_line in current_logs[last_log_count:]:
                        await websocket.send_text(log_line)
                    last_log_count = len(current_logs)

                # If job is completed/failed/cancelled, send final status and close
                if job["status"] in (JobStatus.COMPLETED, JobStatus.FAILED, JobStatus.CANCELLED):
                    await websocket.send_json({"status": job["status"].value, "exit_code": job.get("exit_code")})
                    break

        except WebSocketDisconnect:
            pass
        except Exception as e:
            try:
                await websocket.send_json({"error": str(e)})
            except:
                pass

    @router.post("/api/jobs/{job_id}/cancel")
    async def cancel_job(job_id: str) -> JSONResponse:
        """Cancel a running job.

        Args:
            job_id: Job identifier

        Returns:
            Success message

        Raises:
            HTTPException: If job not found or cannot be cancelled
        """
        success = job_manager.cancel_job(job_id)
        if not success:
            raise HTTPException(status_code=400, detail="Job not found or cannot be cancelled")
        return JSONResponse({"message": "Job cancelled", "job_id": job_id})

    @router.delete("/api/jobs/{job_id}")
    async def delete_job(job_id: str) -> JSONResponse:
        """Delete a job record.

        Args:
            job_id: Job identifier

        Returns:
            Success message

        Raises:
            HTTPException: If job not found
        """
        success = job_manager.delete_job(job_id)
        if not success:
            raise HTTPException(status_code=404, detail="Job not found")
        return JSONResponse({"message": "Job deleted", "job_id": job_id})

    return router

