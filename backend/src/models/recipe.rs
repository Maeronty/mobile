use serde::{Deserialize, Serialize};
use std::collections::HashMap;

// --- Database Entities ---

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Recipe {
    pub id: i64,
    pub user_id: Option<i64>,
    pub title: String,
    pub description: Option<String>,
    pub image_url: Option<String>,
    pub source: Option<String>,
    pub category: String,
    pub cook_time_minutes: i64,
    pub servings: i64,
    pub difficulty: String,
    pub average_rating: f64,
    pub total_ratings: i64,
    pub status: String,
    pub created_at: String,
    pub updated_at: String,
    /// true = `cook_time_minutes` là ước lượng từ nội dung các bước (app hiện "~").
    pub cook_time_estimated: bool,
    /// Calo ước tính cả món (từ nguyên liệu); 0 = chưa tính được.
    pub estimated_calories: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct RecipeNutrition {
    pub recipe_id: i64,
    pub calories: f64,
    pub protein_grams: f64,
    pub fat_grams: f64,
    pub carbs_grams: f64,
    pub fiber_grams: f64,
    pub sugar_grams: f64,
    pub sodium_mg: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct RecipeIngredient {
    pub id: i64,
    pub recipe_id: i64,
    pub name: String,
    pub amount: f64,
    pub unit: String,
    pub sort_order: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct RecipeInstruction {
    pub id: i64,
    pub recipe_id: i64,
    pub step_number: i64,
    pub content: String,
}

// --- DTOs (Data Transfer Objects) ---

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RecipeSummaryDto {
    pub recipe_id: i64,
    #[serde(rename = "recipeID")]
    pub recipe_id_upper: i64,
    pub id: i64,
    pub title: String,
    pub image_url: String,
    pub cook_time_minutes: i64,
    pub difficulty: String,
    pub average_rating: f64,
    pub total_ratings: i64,
    pub category: String,
    pub tags: Vec<String>,
    pub ingredient_names: Vec<String>,
    pub is_favorited: bool,
    pub user_rating: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct IngredientDto {
    pub name: String,
    pub amount: f64,
    pub unit: String,
    pub notes: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct InstructionDto {
    pub step_number: i64,
    pub title: Option<String>,
    pub content: String,
    pub image_url: Option<String>,
    pub estimated_minutes: Option<i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NutritionDto {
    pub calories: f64,
    pub protein_grams: f64,
    pub fat_grams: f64,
    pub carbs_grams: f64,
    pub fiber_grams: f64,
    pub sugar_grams: f64,
    pub sodium_mg: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RecipeDetailDto {
    pub recipe_id: i64,
    #[serde(rename = "recipeID")]
    pub recipe_id_upper: i64,
    pub id: i64,
    pub title: String,
    pub description: Option<String>,
    pub image_url: String,
    pub additional_images: Vec<String>,
    pub cook_time_minutes: i64,
    /// true = thời gian nấu là ước lượng (app hiện "~").
    pub cook_time_estimated: bool,
    pub difficulty: String,
    pub servings: i64,
    pub calories: i64,
    /// true = `calories` là ước tính từ nguyên liệu cho CẢ MÓN (app hiện "~").
    pub calories_estimated: bool,
    pub average_rating: f64,
    pub total_ratings: i64,
    pub user_rating: Option<f64>,
    pub author_name: Option<String>,
    pub source: Option<String>,
    pub ingredients: Vec<IngredientDto>,
    pub instructions: Vec<InstructionDto>,
    pub nutrition: Option<NutritionDto>,
    pub tags: Vec<String>,
    pub is_favorited: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RecipeScoreResult {
    pub recipe_id: i64,
    #[serde(rename = "recipeID")]
    pub recipe_id_upper: i64,
    pub id: i64,
    pub title: String,
    pub image_url: String,
    pub category: String,
    pub cook_time_minutes: i64,
    pub difficulty: String,
    pub average_rating: f64,
    pub total_ratings: i64,
    pub calories: i64,
    pub tags: Vec<String>,
    pub is_favorited: bool,
    pub match_score: f64,
    pub matched_ingredients: Vec<String>,
    pub missing_ingredients: Vec<String>,
    pub reason: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SuggestRequest {
    pub ingredients: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SuggestItemResponse {
    pub id: i64,
    pub title: String,
    pub reason: String,
    pub used: Vec<String>,
    pub missing: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RawCatalogIngredient {
    pub name: String,
    pub amount: f64,
    pub unit: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SpoonacularCatalogItem {
    pub id: i64,
    pub title: String,
    pub image: Option<String>,
    pub source: Option<String>,
    pub category: String,
    pub time: Option<i64>,
    /// true = `time` là ước lượng từ nội dung các bước (app hiện "~").
    #[serde(default, rename = "timeEstimated")]
    pub time_estimated: bool,
    /// Calo ước tính cả món khi `nutrients` rỗng (0 = không rõ).
    #[serde(default, rename = "estimatedCalories")]
    pub estimated_calories: i64,
    pub servings: Option<i64>,
    pub nutrients: HashMap<String, f64>,
    pub steps: Vec<String>,
    pub ingredients: Vec<RawCatalogIngredient>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct IngredientVocabularyItem {
    pub ingredient_id: i64,
    pub name: String,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RecipeStatsDto {
    pub total_recipes: i64,
    pub total_ingredients: i64,
    pub categories_count: i64,
}

// --- Query Parameters ---

#[derive(Debug, Clone, Deserialize, Default)]
pub struct RecipeListQuery {
    pub category: Option<String>,
    #[serde(rename = "maxTime")]
    pub max_time: Option<i64>,
}

#[derive(Debug, Clone, Deserialize, Default)]
pub struct SearchQuery {
    pub term: Option<String>,
}

#[derive(Debug, Clone, Deserialize, Default)]
pub struct IngredientSearchQuery {
    pub ingredients: Option<String>,
}
