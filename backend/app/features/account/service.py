# =============================================================================
# FEATURE: TÀI KHOẢN (đăng ký / đăng nhập)
# =============================================================================
#
# FLOW ĐĂNG KÝ
#   1. Đưa username và email về chữ thường để "An" và "an" là một tài khoản.
#   2. Trùng username hoặc email → lỗi 409.
#   3. Băm mật khẩu, lưu người dùng, cấp token để đăng nhập luôn.
#
# FLOW ĐĂNG NHẬP
#   1. Tìm theo username hoặc email.
#   2. Sai tài khoản hay sai mật khẩu đều trả cùng một lỗi 401, để không lộ
#      tài khoản nào đã tồn tại.
#   3. Đúng → cấp token mới.
#
# LƯU Ý
#   Hai request đăng ký cùng lúc có thể cùng qua bước kiểm tra; khi đó ràng buộc
#   UNIQUE của database chặn lại và IntegrityError cũng được đổi thành 409.
# =============================================================================

from fastapi import HTTPException, status
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.models import Favorite, User
from app.core.security import create_token, hash_password, verify_password_or_dummy
from app.features.account.schemas import AuthOut, LoginIn, RegisterIn, UserOut

_DUPLICATE_MESSAGE = "Tên đăng nhập hoặc email đã được sử dụng"


def build_user_out(db: Session, user: User) -> UserOut:
    return UserOut(**_user_fields(db, user))


def _user_fields(db: Session, user: User) -> dict:
    favorite_count = db.scalar(select(func.count()).select_from(Favorite).where(Favorite.user_id == user.id)) or 0
    return {
        "user_id": user.id,
        "username": user.username,
        "email": user.email,
        "display_name": user.display_name,
        "avatar_url": user.avatar_url,
        "role": user.role,
        "bio": user.bio,
        "favorite_count": favorite_count,
        "saved_recipes_count": favorite_count,
        "cooked_count": user.cooked_count,
        "followers_count": user.followers_count,
        "is_pro": user.is_pro,
        "diet_preference": user.diet_preference,
        "notification_enabled": user.notification_enabled,
    }


def _auth_out(db: Session, user: User) -> AuthOut:
    return AuthOut(**_user_fields(db, user), token=create_token(user.id))


def register(db: Session, data: RegisterIn) -> AuthOut:
    username = data.username.lower()
    email = data.email.lower()

    exists = db.scalar(select(User.id).where(or_(User.username == username, User.email == email)))
    if exists is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, _DUPLICATE_MESSAGE)

    user = User(
        username=username,
        email=email,
        password_hash=hash_password(data.password),
        display_name=data.display_name or data.username,
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, _DUPLICATE_MESSAGE) from None
    return _auth_out(db, user)


def login(db: Session, data: LoginIn) -> AuthOut:
    identifier = data.username_or_email.lower()
    user = db.scalar(select(User).where(or_(User.username == identifier, User.email == identifier)))

    if not verify_password_or_dummy(data.password, user.password_hash if user else None):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Tên đăng nhập hoặc mật khẩu không đúng")
    return _auth_out(db, user)
