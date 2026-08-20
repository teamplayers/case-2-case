from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response

from app.auth import COOKIE, create_token, get_current_user, hash_password, verify_password
from app.db import get_db
from app.models import ChangePasswordIn, LoginIn, RegisterIn, utcnow

router = APIRouter(prefix="/api/auth", tags=["auth"])


def _public_user(user: dict) -> dict:
    return {
        "id": user["id"],
        "username": user["username"],
        "role": user["role"],
        "mustChangePassword": user.get("mustChangePassword", False),
    }


@router.post("/login")
async def login(body: LoginIn, response: Response):
    db = get_db()
    user = await db.users.find_one({"username": body.username})
    if not user or not verify_password(body.password, user["passwordHash"]):
        raise HTTPException(status_code=401, detail="Invalid username or password")
    token = create_token(str(user["_id"]), user["role"])
    response.set_cookie(COOKIE, token, httponly=True, samesite="lax", max_age=7 * 24 * 3600)
    return {
        "token": token,
        "user": {
            "id": str(user["_id"]),
            "username": user["username"],
            "role": user["role"],
            "mustChangePassword": user.get("mustChangePassword", False),
        },
    }


@router.post("/logout")
async def logout(response: Response):
    response.delete_cookie(COOKIE)
    return {"ok": True}


@router.post("/register")
async def register(body: RegisterIn, response: Response):
    db = get_db()
    if await db.users.find_one({"username": body.username}):
        raise HTTPException(status_code=409, detail="Username already taken")
    result = await db.users.insert_one(
        {
            "username": body.username,
            "passwordHash": hash_password(body.password),
            "role": "customer",
            "mustChangePassword": False,
            "createdAt": utcnow(),
        }
    )
    token = create_token(str(result.inserted_id), "customer")
    response.set_cookie(COOKIE, token, httponly=True, samesite="lax", max_age=7 * 24 * 3600)
    return {
        "token": token,
        "user": {
            "id": str(result.inserted_id),
            "username": body.username,
            "role": "customer",
            "mustChangePassword": False,
        },
    }


@router.get("/me")
async def me(user: Annotated[dict, Depends(get_current_user)]):
    return _public_user(user)


@router.post("/change-password")
async def change_password(
    body: ChangePasswordIn,
    user: Annotated[dict, Depends(get_current_user)],
):
    db = get_db()
    doc = await db.users.find_one({"username": user["username"]})
    if not doc or not verify_password(body.current_password, doc["passwordHash"]):
        raise HTTPException(status_code=400, detail="Current password is wrong")
    await db.users.update_one(
        {"_id": doc["_id"]},
        {"$set": {"passwordHash": hash_password(body.new_password), "mustChangePassword": False}},
    )
    return {"ok": True}
