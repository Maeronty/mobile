# =============================================================================
# FEATURE: HỒ SƠ NGƯỜI DÙNG
# =============================================================================
#
# FLOW
#   GET → trả thông tin của người đang đăng nhập, kèm số món đã lưu.
#   PUT → chỉ cập nhật những trường app gửi lên; trường không gửi giữ nguyên.
#
# LƯU Ý
#   Không cho sửa role, isPro hay các bộ đếm qua API này, để người dùng không tự
#   nâng quyền cho mình.
# =============================================================================

from typing import Annotated

from pydantic import StringConstraints
from sqlalchemy.orm import Session

from app.core.models import User
from app.core.schemas import ApiModel
from app.features.account.schemas import UserOut
from app.features.account.service import build_user_out


class ProfileUpdateIn(ApiModel):
    display_name: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)] | None = None
    bio: Annotated[str, StringConstraints(strip_whitespace=True, max_length=500)] | None = None
    avatar_url: Annotated[str, StringConstraints(strip_whitespace=True, max_length=500)] | None = None
    diet_preference: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)] | None = None
    notification_enabled: bool | None = None


def get_profile(db: Session, user: User) -> UserOut:
    return build_user_out(db, user)


def update_profile(db: Session, user: User, data: ProfileUpdateIn) -> UserOut:
    for field, value in data.model_dump(exclude_unset=True).items():
        if value is not None:
            setattr(user, field, value)
    db.commit()
    return build_user_out(db, user)
