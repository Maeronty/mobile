# =============================================================================
# CORE: NẠP DỮ LIỆU CÔNG THỨC BAN ĐẦU
# =============================================================================
#
# FLOW
#   Khởi động BE → bảng `recipes` còn trống → nạp `data/seed_recipes.json`.
#   Đã có dữ liệu → không làm gì, nên chỉnh sửa trong database không bị ghi đè.
#
# LƯU Ý
#   File seed được chuyển từ `lib/core/data/mock_data.dart` của app. Không tạo
#   sẵn tài khoản nào để tránh có tài khoản mật khẩu mặc định.
# =============================================================================

import json
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.models import Ingredient, InstructionStep, Recipe

_SEED_FILE = Path(__file__).resolve().parent.parent / "data" / "seed_recipes.json"


def seed_recipes(db: Session) -> None:
    if db.scalar(select(Recipe.id).limit(1)) is not None:
        return

    for item in json.loads(_SEED_FILE.read_text(encoding="utf-8")):
        nutrition = item["nutrition"]
        db.add(
            Recipe(
                id=item["id"],
                title=item["title"],
                description=item["description"],
                image_asset=item["imageAsset"],
                category=item["category"],
                tags=item["tags"],
                cook_time_minutes=item["cookTimeMinutes"],
                difficulty=item["difficulty"],
                servings=item["servings"],
                calories=item["calories"],
                average_rating=item["averageRating"],
                total_ratings=item["totalRatings"],
                protein_grams=nutrition["proteinGrams"],
                carbs_grams=nutrition["carbsGrams"],
                fat_grams=nutrition["fatGrams"],
                fiber_grams=nutrition["fiberGrams"],
                ingredients=[
                    Ingredient(position=i, name=x["name"], amount=x["amount"], unit=x["unit"], note=x["note"])
                    for i, x in enumerate(item["ingredients"])
                ],
                instructions=[
                    InstructionStep(
                        step_number=x["stepNumber"],
                        description=x["description"],
                        estimated_minutes=x["estimatedMinutes"],
                        tip=x["tip"],
                    )
                    for x in item["instructions"]
                ],
            )
        )
    db.commit()
