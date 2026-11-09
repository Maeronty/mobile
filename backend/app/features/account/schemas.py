# =============================================================================
# FEATURE TÀI KHOẢN: DỮ LIỆU VÀO / RA
# =============================================================================
#
# LƯU Ý
#   Tên trường khớp với `AuthService` và `UserProfile.fromJson` của app.
#   `UserOut` không có mật khẩu hay hash, nên không thể trả nhầm ra ngoài.
# =============================================================================

from typing import Annotated

from pydantic import EmailStr, Field, StringConstraints

from app.core.schemas import ApiModel

Username = Annotated[
    str, StringConstraints(strip_whitespace=True, pattern=r"^[A-Za-z0-9_.-]{3,32}$")
]
Password = Annotated[str, Field(min_length=8, max_length=128)]


class RegisterIn(ApiModel):
    username: Username
    email: EmailStr
    password: Password
    display_name: Annotated[str | None, StringConstraints(strip_whitespace=True, max_length=100)] = None


class LoginIn(ApiModel):
    username_or_email: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=254)]
    password: Annotated[str, Field(max_length=128)]
    remember_me: bool = True


class UserOut(ApiModel):
    user_id: int
    username: str
    email: str
    display_name: str
    avatar_url: str
    role: str
    bio: str
    favorite_count: int
    saved_recipes_count: int
    cooked_count: int
    followers_count: int
    is_pro: bool
    diet_preference: str
    notification_enabled: bool


class AuthOut(UserOut):
    token: str
