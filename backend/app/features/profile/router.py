# Route hồ sơ: chỉ nhận request và gọi service. Tất cả đều yêu cầu đăng nhập.

from fastapi import APIRouter

from app.core.deps import CurrentUser, Db
from app.features.account.schemas import UserOut
from app.features.profile import service
from app.features.profile.service import ProfileUpdateIn

router = APIRouter(prefix="/Profile", tags=["Hồ sơ"])


@router.get("", response_model=UserOut)
def get_profile(db: Db, user: CurrentUser):
    return service.get_profile(db, user)


@router.put("", response_model=UserOut)
def update_profile(data: ProfileUpdateIn, db: Db, user: CurrentUser):
    return service.update_profile(db, user, data)
