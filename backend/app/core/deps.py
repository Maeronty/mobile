# =============================================================================
# CORE: XÁC ĐỊNH NGƯỜI DÙNG CỦA REQUEST
# =============================================================================
#
# HAI KIỂU DÙNG
#   `CurrentUser`  : route bắt buộc đăng nhập, thiếu hoặc sai token → 401.
#   `OptionalUser` : route công khai; token sai được coi như khách, để xem công
#                    thức vẫn chạy được khi token đã hết hạn.
# =============================================================================

from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.models import User
from app.core.security import decode_token

_bearer = HTTPBearer(auto_error=False)

Db = Annotated[Session, Depends(get_db)]


def _resolve_user(credentials: HTTPAuthorizationCredentials | None, db: Session) -> User | None:
    if credentials is None:
        return None
    user_id = decode_token(credentials.credentials)
    return db.get(User, user_id) if user_id is not None else None


def get_optional_user(
    db: Db, credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)]
) -> User | None:
    return _resolve_user(credentials, db)


def get_current_user(
    db: Db, credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)]
) -> User:
    user = _resolve_user(credentials, db)
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Bạn cần đăng nhập để dùng tính năng này")
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]
OptionalUser = Annotated[User | None, Depends(get_optional_user)]
