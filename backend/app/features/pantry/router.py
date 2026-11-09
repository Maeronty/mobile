# Route tủ lạnh: chỉ nhận request và gọi service. Tất cả đều yêu cầu đăng nhập.

from typing import Annotated

from fastapi import APIRouter
from pydantic import StringConstraints

from app.core.deps import CurrentUser, Db
from app.core.schemas import ApiModel
from app.features.pantry import service

router = APIRouter(prefix="/Pantry", tags=["Tủ lạnh"])


class PantryItemIn(ApiModel):
    name: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]


@router.get("", response_model=list[str])
def list_items(db: Db, user: CurrentUser):
    return service.list_items(db, user)


@router.post("", response_model=list[str])
def add_item(data: PantryItemIn, db: Db, user: CurrentUser):
    return service.add_item(db, user, data.name)


@router.delete("", response_model=list[str])
def clear_items(db: Db, user: CurrentUser):
    return service.clear_items(db, user)


@router.delete("/{name}", response_model=list[str])
def remove_item(name: str, db: Db, user: CurrentUser):
    return service.remove_item(db, user, name)
