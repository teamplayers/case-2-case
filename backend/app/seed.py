from app.auth import hash_password
from app.config import settings
from app.db import get_db
from app.models import utcnow


async def seed_admin() -> None:
    db = get_db()
    existing = await db.users.find_one({"username": "admin"})
    if existing:
        return
    await db.users.insert_one(
        {
            "username": "admin",
            "passwordHash": hash_password("admin"),
            "role": "admin",
            "mustChangePassword": True,
            "createdAt": utcnow(),
        }
    )
    settings.data_path.mkdir(parents=True, exist_ok=True)
