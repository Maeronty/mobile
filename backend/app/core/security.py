# =============================================================================
# CORE: BẢO MẬT (mật khẩu & JWT)
# =============================================================================
#
# FLOW
#   Đăng ký → băm mật khẩu bằng Argon2 rồi mới lưu; không lưu mật khẩu gốc.
#   Đăng nhập → so mật khẩu với hash → cấp JWT chứa id người dùng, có hạn dùng.
#   Mỗi request → app gửi `Authorization: Bearer <token>` → `decode_token` lấy id.
#
# LƯU Ý
#   `verify_password_or_dummy` vẫn tốn thời gian băm khi không có tài khoản, để
#   không thể dò tài khoản nào tồn tại qua thời gian phản hồi.
# =============================================================================

from datetime import UTC, datetime, timedelta

import jwt
from pwdlib import PasswordHash

from app.core.config import get_settings

_ALGORITHM = "HS256"
_password_hash = PasswordHash.recommended()
_DUMMY_HASH = _password_hash.hash("bep-viet-dummy-password")


def hash_password(password: str) -> str:
    return _password_hash.hash(password)


def verify_password_or_dummy(password: str, stored_hash: str | None) -> bool:
    if stored_hash is None:
        _password_hash.verify(password, _DUMMY_HASH)
        return False
    return _password_hash.verify(password, stored_hash)


def create_token(user_id: int) -> str:
    settings = get_settings()
    expires_at = datetime.now(UTC) + timedelta(days=settings.jwt_expire_days)
    return jwt.encode({"sub": str(user_id), "exp": expires_at}, settings.jwt_secret, algorithm=_ALGORITHM)


def decode_token(token: str) -> int | None:
    """Trả về id người dùng, hoặc None nếu token sai hay đã hết hạn."""
    try:
        payload = jwt.decode(token, get_settings().jwt_secret, algorithms=[_ALGORITHM])
        return int(payload["sub"])
    except (jwt.InvalidTokenError, KeyError, ValueError):
        return None
