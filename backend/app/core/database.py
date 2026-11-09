# =============================================================================
# CORE: KẾT NỐI DATABASE (SQLite)
# =============================================================================
#
# FLOW
#   1. Tạo engine từ DATABASE_URL, tự tạo thư mục chứa file `.db` nếu chưa có.
#   2. Mỗi kết nối bật `foreign_keys`, vì SQLite mặc định tắt khoá ngoại.
#   3. Mỗi request nhận một Session qua `get_db`, xong thì đóng.
#
# LƯU Ý
#   `check_same_thread=False` cần thiết vì FastAPI chạy route trong nhiều thread;
#   mỗi request vẫn dùng Session riêng nên không chia sẻ dữ liệu giữa các request.
# =============================================================================

from collections.abc import Iterator
from pathlib import Path

from sqlalchemy import create_engine, event
from sqlalchemy.engine import make_url
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import get_settings

_url = make_url(get_settings().database_url)
if _url.database and _url.database != ":memory:":
    Path(_url.database).parent.mkdir(parents=True, exist_ok=True)

engine = create_engine(_url, connect_args={"check_same_thread": False})


@event.listens_for(engine, "connect")
def _enable_foreign_keys(dbapi_connection, _record) -> None:
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()


SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def get_db() -> Iterator[Session]:
    with SessionLocal() as session:
        yield session
