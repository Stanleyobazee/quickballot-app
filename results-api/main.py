import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from routers import results

load_dotenv()

ALLOWED_ORIGINS = os.getenv("CORS_ALLOWED_ORIGINS", "http://localhost:3000").split(",")

app = FastAPI(
    title="QuickBallot Results API",
    description="Read-only results and vote-count aggregation service",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_methods=["GET"],
    allow_headers=["*"],
)

app.include_router(results.router)


@app.get("/health")
async def health():
    return {"status": "ok"}