"""Pydantic models for request/response validation."""

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class JobStatus(str, Enum):
    """Job status enumeration."""

    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


class ExecutionMode(str, Enum):
    """Execution mode enumeration."""

    SYNC = "sync"
    ASYNC = "async"


class TrainingMode(str, Enum):
    """Training execution mode."""

    LOCAL = "local"
    CLUSTER = "cluster"


class ODinWConfigType(str, Enum):
    """ODinW configuration type."""

    TEXT_ONLY = "text_only"
    TEXT_AND_VISUAL = "text_and_visual"
    VISUAL_ONLY = "visual_only"
    TEXT_ONLY_POSITIVE = "text_only_positive"


class RF100VLTrainingRequest(BaseModel):
    """Request model for RF100VL training job."""

    supercategory: str = Field(default="all", description="Supercategory to train on (or 'all' for job array)")
    mode: TrainingMode = Field(default=TrainingMode.LOCAL, description="Execution mode: local or cluster")
    num_gpus: Optional[int] = Field(default=None, description="Number of GPUs per node")
    num_nodes: Optional[int] = Field(default=None, description="Number of nodes for distributed training")
    partition: Optional[str] = Field(default=None, description="SLURM partition name (cluster mode)")
    account: Optional[str] = Field(default=None, description="SLURM account name (cluster mode)")
    qos: Optional[str] = Field(default=None, description="SLURM QOS setting (cluster mode)")
    roboflow_root: Optional[str] = Field(default=None, description="Path to Roboflow VL-100 dataset root")
    experiment_dir: Optional[str] = Field(default=None, description="Path to experiment log directory")
    bpe_path: Optional[str] = Field(default=None, description="Path to BPE vocabulary file")
    base_config: Optional[str] = Field(
        default=None,
        description="Base config file path (default: roboflow_v100_full_ft_100_images.yaml)",
    )
    skip_config_resolution: bool = Field(default=False, description="Skip config path resolution step")
    skip_config_validation: bool = Field(default=False, description="Skip config validation step")
    skip_env_setup: bool = Field(default=False, description="Skip environment setup step")
    skip_data_validation: bool = Field(default=False, description="Skip data validation step")
    dry_run: bool = Field(default=False, description="Show what would be done without executing")
    execution_mode: ExecutionMode = Field(default=ExecutionMode.ASYNC, description="Sync or async execution")


class ODinWTrainingRequest(BaseModel):
    """Request model for ODinW training job."""

    config_type: ODinWConfigType = Field(
        default=ODinWConfigType.TEXT_ONLY,
        description="Config type: text_only, text_and_visual, visual_only, text_only_positive",
    )
    mode: TrainingMode = Field(default=TrainingMode.LOCAL, description="Execution mode: local or cluster")
    num_gpus: Optional[int] = Field(default=None, description="Number of GPUs per node")
    num_nodes: Optional[int] = Field(default=None, description="Number of nodes for distributed training")
    partition: Optional[str] = Field(default=None, description="SLURM partition name (cluster mode)")
    account: Optional[str] = Field(default=None, description="SLURM account name (cluster mode)")
    qos: Optional[str] = Field(default=None, description="SLURM QOS setting (cluster mode)")
    odinw_root: Optional[str] = Field(default=None, description="Path to ODinW dataset root")
    experiment_dir: Optional[str] = Field(default=None, description="Path to experiment log directory")
    bpe_path: Optional[str] = Field(default=None, description="Path to BPE vocabulary file")
    base_config: Optional[str] = Field(
        default=None,
        description="Base config file path (overrides config_type)",
    )
    skip_config_resolution: bool = Field(default=False, description="Skip config path resolution step")
    skip_config_validation: bool = Field(default=False, description="Skip config validation step")
    skip_env_setup: bool = Field(default=False, description="Skip environment setup step")
    skip_data_validation: bool = Field(default=False, description="Skip data validation step")
    dry_run: bool = Field(default=False, description="Show what would be done without executing")
    execution_mode: ExecutionMode = Field(default=ExecutionMode.ASYNC, description="Sync or async execution")


class JobResponse(BaseModel):
    """Response model for job information."""

    job_id: str
    dataset_type: str  # "rf100vl" or "odinw"
    status: JobStatus
    created_at: datetime
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    parameters: dict
    exit_code: Optional[int] = None
    error_message: Optional[str] = None
    log_path: Optional[str] = None


class JobListResponse(BaseModel):
    """Response model for job list."""

    jobs: list[JobResponse]
    total: int


class JobStatusResponse(BaseModel):
    """Response model for job status."""

    job_id: str
    status: JobStatus
    exit_code: Optional[int] = None
    error_message: Optional[str] = None

