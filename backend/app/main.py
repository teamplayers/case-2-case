from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.db import connect, disconnect
from app.routers import auth, cases, users, workspaces
from app.seed import seed_admin


@asynccontextmanager
async def lifespan(_app: FastAPI):
    await connect()
    settings.data_path.mkdir(parents=True, exist_ok=True)
    await seed_admin()
    yield
    await disconnect()


app = FastAPI(title="case2case", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.origins,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(workspaces.router)
app.include_router(cases.router)


@app.get("/api/health")
async def health():
    return {"ok": True}
