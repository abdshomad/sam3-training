"""FastAPI application entry point."""

from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from .job_manager import JobManager
from .routes import create_routes
from .training_executor import TrainingExecutor

# Determine project root (parent of webapp directory)
PROJECT_ROOT = Path(__file__).parent.parent.resolve()

# Initialize components
job_manager = JobManager(PROJECT_ROOT)
training_executor = TrainingExecutor(PROJECT_ROOT, job_manager)

# Create FastAPI app
app = FastAPI(
    title="SAM3 Training Web App",
    description="Web interface for launching and monitoring SAM3 training jobs",
    version="1.0.0",
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify allowed origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routes
router = create_routes(job_manager, training_executor)
app.include_router(router)


@app.get("/api/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "ok", "project_root": str(PROJECT_ROOT)}


# Mount static files (must be after API routes to avoid conflicts)
static_dir = Path(__file__).parent / "static"
if static_dir.exists():
    # Serve index.html at root
    @app.get("/")
    async def read_root():
        index_path = static_dir / "index.html"
        if index_path.exists():
            return FileResponse(str(index_path))
        return {"message": "Static files not found"}
    
    # Serve CSS and JS files
    @app.get("/style.css")
    async def read_css():
        css_path = static_dir / "style.css"
        if css_path.exists():
            return FileResponse(str(css_path))
        raise HTTPException(status_code=404, detail="CSS file not found")
    
    @app.get("/app.js")
    async def read_js():
        js_path = static_dir / "app.js"
        if js_path.exists():
            return FileResponse(str(js_path))
        raise HTTPException(status_code=404, detail="JS file not found")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)

