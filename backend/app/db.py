from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase

from app.config import settings
from app.models import oid, utcnow

client: AsyncIOMotorClient | None = None
db: AsyncIOMotorDatabase | None = None

LEGACY_ROLE_MAP = {"admin": "admin", "agent": "agent", "customer": "customer"}


async def migrate_schema() -> None:
    assert db is not None
    async for doc in db.users.find({}):
        patch: dict = {}
        unset: dict = {}
        if doc.get("role") == "admin" and not doc.get("appRole"):
            patch["appRole"] = "superadmin"
        elif "appRole" not in doc:
            patch["appRole"] = None
        if "status" not in doc:
            patch["status"] = "approved"
        if not doc.get("name"):
            patch["name"] = doc.get("username", "")
        if not doc.get("email"):
            patch["email"] = f"{doc.get('username', 'user')}@local"
        if "role" in doc:
            unset["role"] = ""
        if patch or unset:
            update: dict = {}
            if patch:
                patch["updatedAt"] = utcnow()
                update["$set"] = patch
            if unset:
                update["$unset"] = unset
            await db.users.update_one({"_id": doc["_id"]}, update)

    async for ws in db.workspaces.find({"members": {"$exists": False}}):
        member_ids = list(ws.get("memberIds") or ws.get("agentIds") or [])
        if not member_ids:
            continue
        members = []
        for uid in member_ids:
            user = await db.users.find_one({"_id": uid})
            legacy = user.get("role") if user else "customer"
            members.append({"userId": uid, "role": LEGACY_ROLE_MAP.get(legacy, "customer")})
        await db.workspaces.update_one(
            {"_id": ws["_id"]},
            {"$set": {"members": members, "updatedAt": utcnow()}},
        )


async def connect() -> AsyncIOMotorDatabase:
    global client, db
    client = AsyncIOMotorClient(settings.mongodb_uri)
    db = client[settings.mongodb_db]
    await db.users.create_index("username", unique=True)
    await db.users.create_index("appRole")
    await db.users.create_index("status")
    await migrate_schema()
    await db.users.create_index("email", unique=True)
    await db.cases.create_index("workspaceId")
    await db.cases.create_index("reporterId")
    await db.cases.create_index("assigneeId")
    await db.cases.create_index("stage")
    await db.workspaces.create_index("members.userId")
    await migrate_schema()
    return db


async def disconnect() -> None:
    global client
    if client is not None:
        client.close()
        client = None


def get_db() -> AsyncIOMotorDatabase:
    assert db is not None
    return db
