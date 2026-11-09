# =============================================================================
# CORE: LỚP GỐC CHO JSON TRẢ VỀ APP
# =============================================================================
#
# VAI TRÒ
#   Python dùng snake_case, app Flutter đọc camelCase. Lớp này tự chuyển đổi và
#   cho phép đọc trực tiếp từ object SQLAlchemy.
# =============================================================================

from pydantic import BaseModel, ConfigDict
from pydantic.alias_generators import to_camel


class ApiModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True, from_attributes=True)
