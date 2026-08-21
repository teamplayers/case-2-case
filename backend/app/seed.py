from app.auth import hash_password
from app.config import settings
from app.db import get_db
from app.models import utcnow

DUPER_USERNAME = "duperadmin"
DUPER_PASSWORD = "duperadmin"


async def seed_admin() -> None:
    db = get_db()
    duper = await db.users.find_one({"appRole": "duperadmin"})
    if duper:
        if duper.get("username") == "admin":
            patch = {"username": DUPER_USERNAME, "updatedAt": utcnow()}
            if duper.get("mustChangePassword"):
                patch["passwordHash"] = hash_password(DUPER_PASSWORD)
            await db.users.update_one({"_id": duper["_id"]}, {"$set": patch})
        return
    legacy = await db.users.find_one({"username": "admin"})
    if legacy:
        patch = {
            "username": DUPER_USERNAME,
            "appRole": "duperadmin",
            "status": "approved",
            "name": legacy.get("name") or "Duper Admin",
            "email": legacy.get("email") or "duperadmin@local",
            "updatedAt": utcnow(),
        }
        if legacy.get("mustChangePassword"):
            patch["passwordHash"] = hash_password(DUPER_PASSWORD)
        await db.users.update_one(
            {"_id": legacy["_id"]},
            {"$set": patch, "$unset": {"role": ""}},
        )
        return
    await db.users.insert_one(
        {
            "username": DUPER_USERNAME,
            "name": "Duper Admin",
            "email": "duperadmin@local",
            "passwordHash": hash_password(DUPER_PASSWORD),
            "appRole": "duperadmin",
            "status": "approved",
            "mustChangePassword": True,
            "createdAt": utcnow(),
        }
    )
    settings.data_path.mkdir(parents=True, exist_ok=True)
