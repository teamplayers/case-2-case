from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException

from app.auth import hash_password, require_roles
from app.db import get_db
from app.models import UserCreateIn, serialize, utcnow

router = APIRouter(prefix="/api/users", tags=["users"])


@router.get("")
async def list_users(user: Annotated[dict, Depends(require_roles("admin", "agent"))]):
    db = get_db()
    query: dict = {}
    if user["role"] == "agent":
        query = {"role": {"$in": ["agent", "customer"]}}
    rows = []
    async for doc in db.users.find(query).sort("username", 1):
        pub = serialize(doc)
        assert pub
        pub.pop("passwordHash", None)
        rows.append(pub)
    return rows


@router.post("")
async def create_user(
    body: UserCreateIn,
    _: Annotated[dict, Depends(require_roles("admin"))],
):
    db = get_db()
    if await db.users.find_one({"username": body.username}):
        raise HTTPException(status_code=409, detail="Username already taken")
    result = await db.users.insert_one(
        {
            "username": body.username,
            "passwordHash": hash_password(body.password),
            "role": body.role,
            "mustChangePassword": True,
            "createdAt": utcnow(),
        }
    )
    doc = await db.users.find_one({"_id": result.inserted_id})
    pub = serialize(doc)
    assert pub
    pub.pop("passwordHash", None)
    return pub
