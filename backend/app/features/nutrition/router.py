# Route thực đơn: chỉ nhận request và gọi service. Logic nằm trong `service.py`.
#
# Đây là `def` thường, không phải `async def`: FastAPI chạy nó ở thread riêng nên
# lúc chờ AI (có thể vài chục giây) các request khác không bị chặn.

from fastapi import APIRouter

from app.core.deps import Db, OptionalUser
from app.features.nutrition import service
from app.features.nutrition.schemas import GeneratePlanIn, MealPlanOut

router = APIRouter(prefix="/NutritionAdvisor", tags=["Thực đơn"])


@router.post("/generate-plan", response_model=MealPlanOut)
def generate_plan(data: GeneratePlanIn, db: Db, user: OptionalUser):
    return service.generate_plan(db, data, user)
