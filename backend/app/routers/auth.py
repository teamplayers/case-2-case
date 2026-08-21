from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response

from app.auth import COOKIE, create_token, get_current_user, hash_password, verify_password
from app.db import get_db
from app.models import ChangePasswordIn, LoginIn, RegisterIn, utcnow
from app.permissions import public_user

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post("/login")
async def login(body: LoginIn, response: Response):
    db = get_db()
    user = await db.users.find_one({"username": body.username})
    if not user or not verify_password(body.password, user["passwordHash"]):
        raise HTTPException(status_code=401, detail="Invalid username or password")
    pub = public_user(user)
    if pub["status"] != "approved":
        raise HTTPException(status_code=403, detail="Account pending approval")
    token = create_token(pub["id"], pub.get("appRole"))
    response.set_cookie(COOKIE, token, httponly=True, samesite="lax", max_age=7 * 24 * 3600)
    return {"token": token, "user": pub}


@router.post("/logout")
async def logout(response: Response):
    response.delete_cookie(COOKIE)
    return {"ok": True}


@router.post("/register")
async def register(body: RegisterIn):
    db = get_db()
    username = body.username.strip()
    email = body.email.strip().lower()
    if await db.users.find_one({"username": username}):
        raise HTTPException(status_code=409, detail="Username already taken")
    if await db.users.find_one({"email": email}):
        raise HTTPException(status_code=409, detail="Email already registered")
    await db.users.insert_one(
        {
            "username": username,
            "name": body.name.strip(),
            "email": email,
            "passwordHash": hash_password(body.password),
            "appRole": None,
            "status": "pending",
            "mustChangePassword": False,
            "createdAt": utcnow(),
        }
    )
    return {
        "ok": True,
        "status": "pending",
        "message": "Account created. A SuperAdmin must approve before you can sign in.",
    }


@router.get("/me")
async def me(user: Annotated[dict, Depends(get_current_user)]):
    return user


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
