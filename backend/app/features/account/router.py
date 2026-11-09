# Route tài khoản: chỉ nhận request và gọi service. Logic nằm trong `service.py`.

from fastapi import APIRouter, status

from app.core.deps import Db
from app.features.account import service
from app.features.account.schemas import AuthOut, LoginIn, RegisterIn

router = APIRouter(prefix="/Account", tags=["Tài khoản"])


@router.post("/register", response_model=AuthOut, status_code=status.HTTP_201_CREATED)
def register(data: RegisterIn, db: Db):
    return service.register(db, data)


@router.post("/login", response_model=AuthOut)
def login(data: LoginIn, db: Db):
    return service.login(db, data)
