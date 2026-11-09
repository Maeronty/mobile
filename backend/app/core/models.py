# =============================================================================
# CORE: CÁC BẢNG DATABASE
# =============================================================================
#
# QUAN HỆ
#   users 1─n favorites n─1 recipes   : món yêu thích của từng người
#   users 1─n pantry_items            : tủ lạnh của từng người
#   recipes 1─n ingredients           : nguyên liệu, giữ thứ tự bằng `position`
#   recipes 1─n instruction_steps     : các bước nấu
#
# LƯU Ý
#   Xoá user hoặc recipe sẽ xoá luôn dữ liệu con (`ondelete="CASCADE"`).
# =============================================================================

from sqlalchemy import JSON, Boolean, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    username: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    email: Mapped[str] = mapped_column(String(254), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    display_name: Mapped[str] = mapped_column(String(100))
    avatar_url: Mapped[str] = mapped_column(String(500), default="")
    role: Mapped[str] = mapped_column(String(20), default="Member")
    bio: Mapped[str] = mapped_column(String(500), default="")
    cooked_count: Mapped[int] = mapped_column(Integer, default=0)
    followers_count: Mapped[int] = mapped_column(Integer, default=0)
    is_pro: Mapped[bool] = mapped_column(Boolean, default=False)
    diet_preference: Mapped[str] = mapped_column(String(100), default="Cân bằng & Đa dạng")
    notification_enabled: Mapped[bool] = mapped_column(Boolean, default=True)


class Recipe(Base):
    __tablename__ = "recipes"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(Text)
    image_asset: Mapped[str] = mapped_column(String(300))
    category: Mapped[str] = mapped_column(String(50), index=True)
    tags: Mapped[list[str]] = mapped_column(JSON, default=list)
    cook_time_minutes: Mapped[int] = mapped_column(Integer)
    difficulty: Mapped[str] = mapped_column(String(20))
    servings: Mapped[int] = mapped_column(Integer)
    calories: Mapped[int] = mapped_column(Integer)
    average_rating: Mapped[float] = mapped_column(Float, default=0)
    total_ratings: Mapped[int] = mapped_column(Integer, default=0)
    protein_grams: Mapped[float] = mapped_column(Float, default=0)
    carbs_grams: Mapped[float] = mapped_column(Float, default=0)
    fat_grams: Mapped[float] = mapped_column(Float, default=0)
    fiber_grams: Mapped[float | None] = mapped_column(Float, nullable=True)

    ingredients: Mapped[list["Ingredient"]] = relationship(
        order_by="Ingredient.position", cascade="all, delete-orphan"
    )
    instructions: Mapped[list["InstructionStep"]] = relationship(
        order_by="InstructionStep.step_number", cascade="all, delete-orphan"
    )


class Ingredient(Base):
    __tablename__ = "ingredients"

    id: Mapped[int] = mapped_column(primary_key=True)
    recipe_id: Mapped[int] = mapped_column(ForeignKey("recipes.id", ondelete="CASCADE"), index=True)
    position: Mapped[int] = mapped_column(Integer)
    name: Mapped[str] = mapped_column(String(200))
    amount: Mapped[float] = mapped_column(Float)
    unit: Mapped[str] = mapped_column(String(30))
    note: Mapped[str | None] = mapped_column(String(200), nullable=True)


class InstructionStep(Base):
    __tablename__ = "instruction_steps"

    id: Mapped[int] = mapped_column(primary_key=True)
    recipe_id: Mapped[int] = mapped_column(ForeignKey("recipes.id", ondelete="CASCADE"), index=True)
    step_number: Mapped[int] = mapped_column(Integer)
    description: Mapped[str] = mapped_column(Text)
    estimated_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    tip: Mapped[str | None] = mapped_column(Text, nullable=True)


class Favorite(Base):
    __tablename__ = "favorites"

    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    recipe_id: Mapped[int] = mapped_column(ForeignKey("recipes.id", ondelete="CASCADE"), primary_key=True)


class PantryItem(Base):
    __tablename__ = "pantry_items"
    __table_args__ = (UniqueConstraint("user_id", "normalized_name"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(100))
    normalized_name: Mapped[str] = mapped_column(String(100))
