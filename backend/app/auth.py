from datetime import datetime, timedelta, timezone
from typing import Annotated, Any

import jwt
from fastapi import Cookie, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from passlib.context import CryptContext

from app.config import settings
from app.db import get_db
from app.models import oid
from app.permissions import is_app_operator, public_user

pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")
bearer = HTTPBearer(auto_error=False)

COOKIE = "c2c_token"


def hash_password(password: str) -> str:
    return pwd.hash(password)


def verify_password(password: str, hashed: str) -> bool:
    return pwd.verify(password, hashed)


def create_token(user_id: str, app_role: str | None) -> str:
    payload = {
        "sub": user_id,
        "appRole": app_role,
        "exp": datetime.now(timezone.utc) + timedelta(days=7),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def decode_token(token: str) -> dict[str, Any]:
    try:
        return jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
    except jwt.PyJWTError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token") from exc


async def get_current_user(
    creds: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
    c2c_token: Annotated[str | None, Cookie()] = None,
) -> dict[str, Any]:
    token = creds.credentials if creds else c2c_token
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    payload = decode_token(token)
    db = get_db()
    user = await db.users.find_one({"_id": oid(payload["sub"])})
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return public_user(user)


def require_app_operators():
    async def checker(user: Annotated[dict, Depends(get_current_user)]) -> dict:
        if not is_app_operator(user):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
        return user

    return checker


def require_duperadmin():
    async def checker(user: Annotated[dict, Depends(get_current_user)]) -> dict:
        from app.permissions import is_duperadmin

        if not is_duperadmin(user):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
        return user

    return checker
