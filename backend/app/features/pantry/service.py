# =============================================================================
# FEATURE: TỦ LẠNH (nguyên liệu của từng người dùng)
# =============================================================================
#
# FLOW
#   Thêm → chuẩn hoá tên để so trùng → đã có thì bỏ qua, chưa có thì lưu.
#   Xoá một món / dọn sạch tủ → chỉ tác động tới dữ liệu của người đang đăng nhập.
#   Mọi thao tác trả về danh sách mới để app cập nhật luôn.
#
# LƯU Ý
#   Tên giữ nguyên cách người dùng gõ, cột `normalized_name` chỉ dùng để so trùng.
#   Thêm trùng không báo lỗi, giống `PantryController` trong app.
# =============================================================================

from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.models import PantryItem, User
from app.core.text import normalize_text


def list_items(db: Session, user: User) -> list[str]:
    query = select(PantryItem.name).where(PantryItem.user_id == user.id).order_by(PantryItem.id)
    return list(db.scalars(query))


def add_item(db: Session, user: User, name: str) -> list[str]:
    normalized = normalize_text(name)
    existing = db.scalar(
        select(PantryItem.id).where(PantryItem.user_id == user.id, PantryItem.normalized_name == normalized)
    )
    if existing is None:
        db.add(PantryItem(user_id=user.id, name=name.strip(), normalized_name=normalized))
        try:
            db.commit()
        except IntegrityError:
            # Hai request thêm cùng lúc: bản kia đã lưu, kết quả vẫn đúng.
            db.rollback()
    return list_items(db, user)


def remove_item(db: Session, user: User, name: str) -> list[str]:
    db.execute(
        delete(PantryItem).where(PantryItem.user_id == user.id, PantryItem.normalized_name == normalize_text(name))
    )
    db.commit()
    return list_items(db, user)


def clear_items(db: Session, user: User) -> list[str]:
    db.execute(delete(PantryItem).where(PantryItem.user_id == user.id))
    db.commit()
    return []
