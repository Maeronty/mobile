# =============================================================================
# ĐIỂM KHỞI ĐỘNG BACKEND BẾP VIỆT
# =============================================================================
#
# FLOW KHỞI ĐỘNG
#   1. Đọc cấu hình; thiếu JWT_SECRET thì dừng với thông báo lỗi.
#   2. Tạo bảng còn thiếu, nạp công thức nếu database còn trống.
#   3. Gắn các feature vào `/api`, mở Swagger tại `/swagger/index.html`.
#
# ĐỊNH DẠNG LỖI
#   Mọi lỗi trả về `{"message": "..."}`, là trường `ApiClient` của app đọc.
#   Lỗi kiểm tra dữ liệu không trả lại giá trị đã nhập, để mật khẩu không bị lộ
#   trong response hay log.
#
# LƯU Ý
#   `create_all` chỉ tạo bảng mới, không sửa bảng đã có. Khi đổi cấu trúc bảng
#   trên dữ liệu thật cần công cụ migration như Alembic.
# =============================================================================

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core import models  # noqa: F401 - đăng ký các bảng với Base
from app.core.config import get_settings
from app.core.database import Base, SessionLocal, engine
from app.core.seed import seed_recipes
from app.features.account.router import router as account_router
from app.features.nutrition.router import router as nutrition_router
from app.features.pantry.router import router as pantry_router
from app.features.profile.router import router as profile_router
from app.features.recipes.router import router as recipes_router


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    Base.metadata.create_all(engine)
    with SessionLocal() as db:
        seed_recipes(db)
    yield


app = FastAPI(
    title="Bếp Việt API",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/swagger/index.html",
    redoc_url=None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=get_settings().cors_origin_regex,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(StarletteHTTPException)
async def _http_error(_request: Request, exc: StarletteHTTPException) -> JSONResponse:
    return JSONResponse({"message": exc.detail}, status_code=exc.status_code, headers=exc.headers)


@app.exception_handler(RequestValidationError)
async def _validation_error(_request: Request, exc: RequestValidationError) -> JSONResponse:
    errors = [
        {"field": ".".join(str(part) for part in e["loc"] if part != "body"), "error": e["msg"]}
        for e in exc.errors()
    ]
    return JSONResponse(
        {"message": "Dữ liệu gửi lên không hợp lệ", "errors": errors},
        status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
    )


@app.get("/health", tags=["Hệ thống"])
def health() -> dict:
    return {"status": "ok", "aiEnabled": get_settings().ai_enabled}


for router in (account_router, recipes_router, pantry_router, profile_router, nutrition_router):
    app.include_router(router, prefix="/api")
