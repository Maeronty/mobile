use sqlx::SqlitePool;
use std::collections::HashMap;

use crate::error::AppError;
use crate::services::cook_time;
use crate::models::recipe::{
    IngredientDto, IngredientVocabularyItem, InstructionDto, NutritionDto, RawCatalogIngredient,
    Recipe, RecipeDetailDto, RecipeIngredient, RecipeInstruction, RecipeNutrition,
    RecipeScoreResult, RecipeStatsDto, RecipeSummaryDto, SpoonacularCatalogItem,
    SuggestItemResponse, SuggestRequest,
};

pub async fn get_catalog(pool: &SqlitePool) -> Result<Vec<SpoonacularCatalogItem>, AppError> {
    let recipes: Vec<Recipe> = sqlx::query_as("SELECT * FROM recipes ORDER BY id ASC")
        .fetch_all(pool)
        .await
        .map_err(AppError::Database)?;

    let nutritions: Vec<RecipeNutrition> = sqlx::query_as("SELECT * FROM recipe_nutritions")
        .fetch_all(pool)
        .await
        .map_err(AppError::Database)?;
    let nutrition_map: HashMap<i64, RecipeNutrition> =
        nutritions.into_iter().map(|n| (n.recipe_id, n)).collect();

    let ingredients: Vec<RecipeIngredient> =
        sqlx::query_as("SELECT * FROM recipe_ingredients ORDER BY sort_order ASC, id ASC")
            .fetch_all(pool)
            .await
            .map_err(AppError::Database)?;
    let mut ingredients_map: HashMap<i64, Vec<RawCatalogIngredient>> = HashMap::new();
    for ing in ingredients {
        ingredients_map
            .entry(ing.recipe_id)
            .or_default()
            .push(RawCatalogIngredient {
                name: ing.name,
                amount: ing.amount,
                unit: ing.unit,
            });
    }

    let instructions: Vec<RecipeInstruction> =
        sqlx::query_as("SELECT * FROM recipe_instructions ORDER BY step_number ASC, id ASC")
            .fetch_all(pool)
            .await
            .map_err(AppError::Database)?;
    let mut steps_map: HashMap<i64, Vec<String>> = HashMap::new();
    for inst in instructions {
        steps_map
            .entry(inst.recipe_id)
            .or_default()
            .push(inst.content);
    }

    let mut catalog = Vec::with_capacity(recipes.len());
    for r in recipes {
        let mut nutrients = HashMap::new();
        if let Some(n) = nutrition_map.get(&r.id) {
            nutrients.insert("Calories".to_string(), n.calories);
            nutrients.insert("Protein".to_string(), n.protein_grams);
            nutrients.insert("Fat".to_string(), n.fat_grams);
            nutrients.insert("Carbohydrates".to_string(), n.carbs_grams);
            nutrients.insert("Fiber".to_string(), n.fiber_grams);
            nutrients.insert("Sugar".to_string(), n.sugar_grams);
            nutrients.insert("Sodium".to_string(), n.sodium_mg);
        }

        let steps = steps_map.remove(&r.id).unwrap_or_default();
        let ings = ingredients_map.remove(&r.id).unwrap_or_default();

        catalog.push(SpoonacularCatalogItem {
            id: r.id,
            title: r.title,
            image: r.image_url,
            source: r.source,
            category: r.category,
            time: Some(r.cook_time_minutes),
            time_estimated: r.cook_time_estimated,
            estimated_calories: r.estimated_calories,
            servings: Some(r.servings),
            nutrients,
            steps,
            ingredients: ings,
        });
    }

    Ok(catalog)
}

pub async fn list_recipes(
    pool: &SqlitePool,
    category: Option<&str>,
    max_time: Option<i64>,
    user_id: Option<i64>,
) -> Result<Vec<RecipeSummaryDto>, AppError> {
    let mut favorite_ids = std::collections::HashSet::new();
    if let Some(uid) = user_id {
        let rows: Vec<(i64,)> =
            sqlx::query_as("SELECT recipe_id FROM user_favorites WHERE user_id = ?")
                .bind(uid)
                .fetch_all(pool)
                .await
                .map_err(AppError::Database)?;
        for (rid,) in rows {
            favorite_ids.insert(rid);
        }
    }

    let recipes: Vec<Recipe> = sqlx::query_as("SELECT * FROM recipes ORDER BY id ASC")
        .fetch_all(pool)
        .await
        .map_err(AppError::Database)?;

    let ingredients: Vec<RecipeIngredient> =
        sqlx::query_as("SELECT * FROM recipe_ingredients ORDER BY sort_order ASC, id ASC")
            .fetch_all(pool)
            .await
            .map_err(AppError::Database)?;
    let mut ing_names_map: HashMap<i64, Vec<String>> = HashMap::new();
    for ing in ingredients {
        ing_names_map
            .entry(ing.recipe_id)
            .or_default()
            .push(ing.name);
    }

    let summaries: Vec<RecipeSummaryDto> = recipes
        .into_iter()
        .filter(|r| {
            if let Some(cat) = category {
                let cat_clean = cat.trim();
                if !cat_clean.is_empty()
                    && !r.category.trim().eq_ignore_ascii_case(cat_clean)
                    && r.category.trim().to_lowercase() != cat_clean.to_lowercase()
                {
                    return false;
                }
            }
            if let Some(mt) = max_time {
                if r.cook_time_minutes > mt {
                    return false;
                }
            }
            true
        })
        .map(|r| {
            let ing_names = ing_names_map.remove(&r.id).unwrap_or_default();
            let is_fav = favorite_ids.contains(&r.id);
            RecipeSummaryDto {
                recipe_id: r.id,
                recipe_id_upper: r.id,
                id: r.id,
                title: r.title,
                image_url: r.image_url.unwrap_or_default(),
                cook_time_minutes: r.cook_time_minutes,
                difficulty: r.difficulty,
                average_rating: r.average_rating,
                total_ratings: r.total_ratings,
                category: r.category.clone(),
                tags: vec![r.category],
                ingredient_names: ing_names,
                is_favorited: is_fav,
                user_rating: None,
            }
        })
        .collect();

    Ok(summaries)
}

pub async fn get_recipe_by_id(
    pool: &SqlitePool,
    id: i64,
    user_id: Option<i64>,
) -> Result<RecipeDetailDto, AppError> {
    let recipe: Option<Recipe> = sqlx::query_as("SELECT * FROM recipes WHERE id = ?")
        .bind(id)
        .fetch_optional(pool)
        .await
        .map_err(AppError::Database)?;

    let r = recipe.ok_or_else(|| AppError::NotFound("Không tìm thấy công thức món ăn.".to_string()))?;

    let is_favorited = if let Some(uid) = user_id {
        let count: (i64,) =
            sqlx::query_as("SELECT COUNT(*) FROM user_favorites WHERE user_id = ? AND recipe_id = ?")
                .bind(uid)
                .bind(id)
                .fetch_one(pool)
                .await
                .map_err(AppError::Database)?;
        count.0 > 0
    } else {
        false
    };

    let ingredients: Vec<RecipeIngredient> = sqlx::query_as(
        "SELECT * FROM recipe_ingredients WHERE recipe_id = ? ORDER BY sort_order ASC, id ASC",
    )
    .bind(id)
    .fetch_all(pool)
    .await
    .map_err(AppError::Database)?;

    let ingredient_dtos: Vec<IngredientDto> = ingredients
        .into_iter()
        .map(|i| IngredientDto {
            name: i.name,
            amount: i.amount,
            unit: i.unit,
            notes: None,
        })
        .collect();

    let instructions: Vec<RecipeInstruction> = sqlx::query_as(
        "SELECT * FROM recipe_instructions WHERE recipe_id = ? ORDER BY step_number ASC, id ASC",
    )
    .bind(id)
    .fetch_all(pool)
    .await
    .map_err(AppError::Database)?;

    // Thời gian từng bước = thời gian GHI TRONG bước đó (VD "ướp 30 phút");
    // bước không ghi → None, không chia đều tổng thời gian nữa.
    let instruction_dtos: Vec<InstructionDto> = instructions
        .into_iter()
        .map(|inst| InstructionDto {
            step_number: inst.step_number,
            title: None,
            estimated_minutes: cook_time::displayed_step_minutes(&inst.content),
            content: inst.content,
            image_url: None,
        })
        .collect();

    let nutrition: Option<RecipeNutrition> =
        sqlx::query_as("SELECT * FROM recipe_nutritions WHERE recipe_id = ?")
            .bind(id)
            .fetch_optional(pool)
            .await
            .map_err(AppError::Database)?;

    let (nutrition_dto, calories) = if let Some(n) = nutrition {
        let cal = n.calories.round() as i64;
        (
            Some(NutritionDto {
                calories: n.calories,
                protein_grams: n.protein_grams,
                fat_grams: n.fat_grams,
                carbs_grams: n.carbs_grams,
                fiber_grams: n.fiber_grams,
                sugar_grams: n.sugar_grams,
                sodium_mg: n.sodium_mg,
            }),
            cal,
        )
    } else {
        // Không có dữ liệu dinh dưỡng → calo ước tính từ nguyên liệu (0 = không rõ).
        (None, r.estimated_calories)
    };
    let calories_estimated = nutrition_dto.is_none() && calories > 0;

    Ok(RecipeDetailDto {
        recipe_id: r.id,
        recipe_id_upper: r.id,
        id: r.id,
        title: r.title,
        description: r.description,
        image_url: r.image_url.unwrap_or_default(),
        additional_images: vec![],
        cook_time_minutes: r.cook_time_minutes,
        cook_time_estimated: r.cook_time_estimated,
        difficulty: r.difficulty,
        servings: r.servings,
        calories,
        calories_estimated,
        average_rating: r.average_rating,
        total_ratings: r.total_ratings,
        user_rating: None,
        author_name: r.source.clone(),
        source: r.source,
        ingredients: ingredient_dtos,
        instructions: instruction_dtos,
        nutrition: nutrition_dto,
        tags: vec![r.category],
        is_favorited,
    })
}

pub async fn search_recipes(
    pool: &SqlitePool,
    term: &str,
    user_id: Option<i64>,
) -> Result<Vec<RecipeSummaryDto>, AppError> {
    let term_trimmed = term.trim();
    if term_trimmed.is_empty() {
        return Ok(vec![]);
    }
    let term_lower = term_trimmed.to_lowercase();

    let mut favorite_ids = std::collections::HashSet::new();
    if let Some(uid) = user_id {
        let rows: Vec<(i64,)> =
            sqlx::query_as("SELECT recipe_id FROM user_favorites WHERE user_id = ?")
                .bind(uid)
                .fetch_all(pool)
                .await
                .map_err(AppError::Database)?;
        for (rid,) in rows {
            favorite_ids.insert(rid);
        }
    }

    let recipes: Vec<Recipe> = sqlx::query_as("SELECT * FROM recipes ORDER BY id ASC")
        .fetch_all(pool)
        .await
        .map_err(AppError::Database)?;

    let ingredients: Vec<RecipeIngredient> =
        sqlx::query_as("SELECT * FROM recipe_ingredients ORDER BY sort_order ASC, id ASC")
            .fetch_all(pool)
            .await
            .map_err(AppError::Database)?;
    let mut ing_names_map: HashMap<i64, Vec<String>> = HashMap::new();
    for ing in ingredients {
        ing_names_map
            .entry(ing.recipe_id)
            .or_default()
            .push(ing.name);
    }

    let mut matched_with_score: Vec<(Recipe, usize)> = Vec::new();

    for r in recipes {
        let title_lower = r.title.to_lowercase();
        let desc_lower = r.description.as_deref().unwrap_or("").to_lowercase();
        let cat_lower = r.category.to_lowercase();
        let ings = ing_names_map.get(&r.id).cloned().unwrap_or_default();

        let title_match = title_lower.contains(&term_lower);
        let desc_match = desc_lower.contains(&term_lower);
        let cat_match = cat_lower.contains(&term_lower);
        let ing_match = ings.iter().any(|i| i.to_lowercase().contains(&term_lower));

        if title_match || desc_match || cat_match || ing_match {
            // Rank relevance: title match highest, then ing, then cat, then desc
            let rank = if title_match {
                4
            } else if ing_match {
                3
            } else if cat_match {
                2
            } else {
                1
            };
            matched_with_score.push((r, rank));
        }
    }

    matched_with_score.sort_by(|a, b| {
        b.1.cmp(&a.1)
            .then_with(|| b.0.average_rating.partial_cmp(&a.0.average_rating).unwrap_or(std::cmp::Ordering::Equal))
    });

    let summaries = matched_with_score
        .into_iter()
        .map(|(r, _)| {
            let ing_names = ing_names_map.remove(&r.id).unwrap_or_default();
            let is_fav = favorite_ids.contains(&r.id);
            RecipeSummaryDto {
                recipe_id: r.id,
                recipe_id_upper: r.id,
                id: r.id,
                title: r.title,
                image_url: r.image_url.unwrap_or_default(),
                cook_time_minutes: r.cook_time_minutes,
                difficulty: r.difficulty,
                average_rating: r.average_rating,
                total_ratings: r.total_ratings,
                category: r.category.clone(),
                tags: vec![r.category],
                ingredient_names: ing_names,
                is_favorited: is_fav,
                user_rating: None,
            }
        })
        .collect();

    Ok(summaries)
}

fn is_classifier(word: &str) -> bool {
    matches!(
        word,
        "thịt" | "nước" | "dầu" | "cá" | "bột" | "rau" | "cà" | "súp" | "hành"
    )
}

fn ingredient_matches(user_ing: &str, recipe_ing: &str) -> bool {
    let u = user_ing.trim().to_lowercase();
    let r = recipe_ing.trim().to_lowercase();

    if u.is_empty() || r.is_empty() {
        return false;
    }

    // Exact match is always true
    if r == u {
        return true;
    }

    // Substring or single-letter checks must NOT explode on single-character queries like "t"
    if u.chars().count() < 2 {
        return false;
    }

    let u_words: Vec<&str> = u.split_whitespace().collect();
    let r_words: Vec<&str> = r.split_whitespace().collect();

    if u_words.is_empty() || r_words.is_empty() {
        return false;
    }

    let u_first_is_classifier = is_classifier(u_words[0]);
    let r_first_is_classifier = is_classifier(r_words[0]);

    // Handle compound ingredients starting with classifiers
    if u_first_is_classifier && r_first_is_classifier {
        if u_words[0] != r_words[0] {
            // Different classifier heads (e.g. "thịt bò" vs "nước dùng bò")
            // Must share at least one non-classifier substantive word (e.g. "bò")
            let u_substantive: Vec<&str> = u_words[1..].iter().copied().filter(|w| !is_classifier(w)).collect();
            let r_substantive: Vec<&str> = r_words[1..].iter().copied().filter(|w| !is_classifier(w)).collect();
            return u_substantive.iter().any(|uw| r_substantive.contains(uw));
        }

        // Both start with the same classifier head (e.g. "thịt heo" vs "thịt bò")
        let u_rem = &u_words[1..];
        let r_rem = &r_words[1..];

        if !u_rem.is_empty() && !r_rem.is_empty() {
            // Both have qualifiers beyond the classifier: the remaining words MUST match or overlap
            return u_rem.iter().any(|uw| {
                !is_classifier(uw) && r_rem.iter().any(|rw| rw == uw)
            });
        } else if u_rem.is_empty() && r_rem.is_empty() {
            return true;
        } else {
            // One is generic classifier alone (e.g. "thịt"), user queries generic meat matching recipe specific meat
            return true;
        }
    }

    // Phrase containment: if u or r is a multi-word phrase, check containment
    if ((u_words.len() > 1 && r.contains(&u)) || (r_words.len() > 1 && u.contains(&r)))
        && !is_classifier(&u)
        && !is_classifier(&r)
    {
        return true;
    }

    // Full word match for single word queries (e.g. "bò" in "thịt bò")
    if u_words.len() == 1 {
        let uw = u_words[0];
        if !is_classifier(uw) && r_words.iter().any(|rw| rw == &uw) {
            return true;
        }
    }

    // Full word match if recipe ingredient is a single word in user query
    if r_words.len() == 1 {
        let rw = r_words[0];
        if !is_classifier(rw) && u_words.iter().any(|uw| uw == &rw) {
            return true;
        }
    }

    // Check word overlap for Vietnamese compound ingredients requiring at least one non-classifier substantive word
    let u_substantive: Vec<&str> = u_words.iter().copied().filter(|w| !is_classifier(w) && w.chars().count() >= 2).collect();
    let r_substantive: Vec<&str> = r_words.iter().copied().filter(|w| !is_classifier(w) && w.chars().count() >= 2).collect();

    for uw in &u_substantive {
        if r_substantive.iter().any(|rw| rw == uw) {
            return true;
        }
    }

    false
}

pub async fn search_by_ingredients(
    pool: &SqlitePool,
    ingredients_str: &str,
    user_id: Option<i64>,
) -> Result<Vec<RecipeScoreResult>, AppError> {
    let mut user_ings: Vec<String> = ingredients_str
        .split(',')
        .map(|s| s.trim().to_lowercase())
        .filter(|s| !s.is_empty())
        .collect();
    user_ings.sort();
    user_ings.dedup();

    if user_ings.is_empty() {
        return Err(AppError::BadRequest(
            "Danh sách nguyên liệu không được để trống.".to_string(),
        ));
    }

    let mut favorite_ids = std::collections::HashSet::new();
    if let Some(uid) = user_id {
        let rows: Vec<(i64,)> =
            sqlx::query_as("SELECT recipe_id FROM user_favorites WHERE user_id = ?")
                .bind(uid)
                .fetch_all(pool)
                .await
                .map_err(AppError::Database)?;
        for (rid,) in rows {
            favorite_ids.insert(rid);
        }
    }

    let recipes: Vec<Recipe> = sqlx::query_as("SELECT * FROM recipes ORDER BY id ASC")
        .fetch_all(pool)
        .await
        .map_err(AppError::Database)?;

    let nutritions: Vec<RecipeNutrition> = sqlx::query_as("SELECT * FROM recipe_nutritions")
        .fetch_all(pool)
        .await
        .map_err(AppError::Database)?;
    let calories_map: HashMap<i64, i64> = nutritions
        .into_iter()
        .map(|n| (n.recipe_id, n.calories.round() as i64))
        .collect();

    let ingredients: Vec<RecipeIngredient> =
        sqlx::query_as("SELECT * FROM recipe_ingredients ORDER BY sort_order ASC, id ASC")
            .fetch_all(pool)
            .await
            .map_err(AppError::Database)?;
    let mut recipe_ings_map: HashMap<i64, Vec<String>> = HashMap::new();
    for ing in ingredients {
        recipe_ings_map
            .entry(ing.recipe_id)
            .or_default()
            .push(ing.name);
    }

    let mut results = Vec::new();

    for r in recipes {
        let r_ings = recipe_ings_map.get(&r.id).cloned().unwrap_or_default();
        if r_ings.is_empty() {
            continue;
        }

        let mut matched_ings = Vec::new();
        for u in &user_ings {
            let matches_some_ing = r_ings.iter().any(|ring| ingredient_matches(u, ring));
            let matches_title = if u.chars().count() >= 2 {
                let title_lower = r.title.to_lowercase();
                if u.contains(' ') {
                    title_lower.contains(u)
                } else if !is_classifier(u) {
                    title_lower.split_whitespace().any(|tw| tw == u)
                } else {
                    false
                }
            } else {
                false
            };
            if matches_some_ing || matches_title {
                matched_ings.push(u.clone());
            }
        }
        matched_ings.dedup();

        if matched_ings.is_empty() {
            continue;
        }

        let mut missing_ings = Vec::new();
        let mut seen_missing = std::collections::HashSet::new();
        for ring in &r_ings {
            let matched = user_ings
                .iter()
                .any(|u| ingredient_matches(u, ring));
            if !matched && seen_missing.insert(ring.to_lowercase()) {
                missing_ings.push(ring.clone());
            }
        }

        let raw_score = matched_ings.len() as f64 / user_ings.len() as f64;
        let match_score = (raw_score * 100.0).round() / 100.0;
        let reason = format!(
            "Khớp {}/{} nguyên liệu chính trong tủ lạnh của bạn.",
            matched_ings.len(),
            user_ings.len()
        );

        let calories = calories_map.get(&r.id).copied().unwrap_or(0);
        let is_fav = favorite_ids.contains(&r.id);

        results.push(RecipeScoreResult {
            recipe_id: r.id,
            recipe_id_upper: r.id,
            id: r.id,
            title: r.title,
            image_url: r.image_url.unwrap_or_default(),
            category: r.category.clone(),
            cook_time_minutes: r.cook_time_minutes,
            difficulty: r.difficulty,
            average_rating: r.average_rating,
            total_ratings: r.total_ratings,
            calories,
            tags: vec![r.category],
            is_favorited: is_fav,
            match_score,
            matched_ingredients: matched_ings,
            missing_ingredients: missing_ings,
            reason,
        });
    }

    results.sort_by(|a, b| {
        b.match_score
            .partial_cmp(&a.match_score)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then_with(|| {
                b.average_rating
                    .partial_cmp(&a.average_rating)
                    .unwrap_or(std::cmp::Ordering::Equal)
            })
    });

    Ok(results)
}

pub async fn suggest_recipes(
    pool: &SqlitePool,
    request: &SuggestRequest,
) -> Result<Vec<SuggestItemResponse>, AppError> {
    let mut user_ings: Vec<String> = request
        .ingredients
        .iter()
        .map(|s| s.trim().to_lowercase())
        .filter(|s| !s.is_empty())
        .collect();
    user_ings.sort();
    user_ings.dedup();

    if user_ings.is_empty() {
        return Err(AppError::BadRequest(
            "Danh sách nguyên liệu không được để trống.".to_string(),
        ));
    }

    let recipes: Vec<Recipe> = sqlx::query_as("SELECT * FROM recipes ORDER BY id ASC")
        .fetch_all(pool)
        .await
        .map_err(AppError::Database)?;

    let ingredients: Vec<RecipeIngredient> =
        sqlx::query_as("SELECT * FROM recipe_ingredients ORDER BY sort_order ASC, id ASC")
            .fetch_all(pool)
            .await
            .map_err(AppError::Database)?;
    let mut recipe_ings_map: HashMap<i64, Vec<String>> = HashMap::new();
    for ing in ingredients {
        recipe_ings_map
            .entry(ing.recipe_id)
            .or_default()
            .push(ing.name);
    }

    let mut suggestions = Vec::new();

    for r in recipes {
        let r_ings = recipe_ings_map.get(&r.id).cloned().unwrap_or_default();
        if r_ings.is_empty() {
            continue;
        }

        let mut used = Vec::new();
        for u in &user_ings {
            let matches_some_ing = r_ings.iter().any(|ring| ingredient_matches(u, ring));
            let matches_title = if u.chars().count() >= 2 {
                let title_lower = r.title.to_lowercase();
                if u.contains(' ') {
                    title_lower.contains(u)
                } else if !is_classifier(u) {
                    title_lower.split_whitespace().any(|tw| tw == u)
                } else {
                    false
                }
            } else {
                false
            };
            if matches_some_ing || matches_title {
                used.push(u.clone());
            }
        }
        used.dedup();

        if used.is_empty() {
            continue;
        }

        let mut missing = Vec::new();
        let mut seen_missing = std::collections::HashSet::new();
        for ring in &r_ings {
            // Dòng nhóm của dữ liệu cào ("Gia vị: muối, tiêu", "DỤNG CỤ: khuôn...")
            // là gia vị / đồ ăn kèm / dụng cụ, không tính là nguyên liệu cần mua.
            if is_group_line(ring) {
                continue;
            }
            let matched = user_ings
                .iter()
                .any(|u| ingredient_matches(u, ring));
            if !matched && seen_missing.insert(ring.to_lowercase()) {
                missing.push(ring.clone());
            }
        }

        // Chỉ nêu điều so khớp được thật sự, không tự nhận xét về dinh dưỡng.
        let reason = if used.len() == 1 {
            format!("Tận dụng {} bạn đang có.", used[0])
        } else {
            let last = used.last().unwrap();
            let prefix = used[..used.len() - 1].join(", ");
            format!("Tận dụng {} và {} bạn đang có.", prefix, last)
        };

        suggestions.push(SuggestItemResponse {
            id: r.id,
            title: r.title,
            reason,
            used,
            missing,
        });
    }

    // Dùng được nhiều nguyên liệu nhất lên đầu, cùng số thì món cần mua ít hơn.
    suggestions.sort_by(|a, b| {
        b.used
            .len()
            .cmp(&a.used.len())
            .then_with(|| a.missing.len().cmp(&b.missing.len()))
    });
    suggestions.truncate(MAX_SUGGESTIONS);

    Ok(suggestions)
}

/// Số món gợi ý tối đa trả về (đủ để chọn, không đổ cả nghìn món về app).
const MAX_SUGGESTIONS: usize = 30;

/// "Gia vị: muối, tiêu" / "DỤNG CỤ: khuôn" — nhãn ngắn, không có chữ số, rồi dấu ":".
fn is_group_line(name: &str) -> bool {
    match name.split_once(':') {
        Some((label, _)) => {
            let label = label.trim();
            let len = label.chars().count();
            (2..=40).contains(&len) && !label.chars().any(|c| c.is_ascii_digit())
        }
        None => false,
    }
}

pub async fn get_ingredients_list(
    pool: &SqlitePool,
) -> Result<Vec<IngredientVocabularyItem>, AppError> {
    let rows: Vec<(i64, String)> = sqlx::query_as(
        r#"
        SELECT MIN(id) as ingredient_id, name
        FROM recipe_ingredients
        GROUP BY LOWER(TRIM(name))
        ORDER BY name ASC
        "#,
    )
    .fetch_all(pool)
    .await
    .map_err(AppError::Database)?;

    let items = rows
        .into_iter()
        .map(|(ingredient_id, name)| IngredientVocabularyItem {
            ingredient_id,
            name,
            created_at: "2026-01-01T00:00:00Z".to_string(),
        })
        .collect();

    Ok(items)
}

pub async fn get_stats(pool: &SqlitePool) -> Result<RecipeStatsDto, AppError> {
    let (total_recipes,): (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipes")
        .fetch_one(pool)
        .await
        .map_err(AppError::Database)?;

    let (total_ingredients,): (i64,) =
        sqlx::query_as("SELECT COUNT(DISTINCT LOWER(TRIM(name))) FROM recipe_ingredients")
            .fetch_one(pool)
            .await
            .map_err(AppError::Database)?;

    let (categories_count,): (i64,) =
        sqlx::query_as("SELECT COUNT(DISTINCT LOWER(TRIM(category))) FROM recipes")
            .fetch_one(pool)
            .await
            .map_err(AppError::Database)?;

    Ok(RecipeStatsDto {
        total_recipes,
        total_ingredients,
        categories_count,
    })
}
