from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase

from app.config import settings

client: AsyncIOMotorClient | None = None
db: AsyncIOMotorDatabase | None = None


async def connect() -> AsyncIOMotorDatabase:
    global client, db
    client = AsyncIOMotorClient(settings.mongodb_uri)
    db = client[settings.mongodb_db]
    await db.users.create_index("username", unique=True)
    await db.cases.create_index("workspaceId")
    await db.cases.create_index("reporterId")
    await db.cases.create_index("assigneeId")
    await db.cases.create_index("stage")
    return db


async def disconnect() -> None:
    global client
    if client is not None:
        client.close()
        client = None


def get_db() -> AsyncIOMotorDatabase:
    assert db is not None
    return db
