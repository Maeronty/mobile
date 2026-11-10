use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct UserFavorite {
    pub user_id: i64,
    pub recipe_id: i64,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ToggleFavoriteResponse {
    pub message: String,
    pub is_favorited: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SyncFavoritesResponse {
    pub message: String,
    pub synced_count: usize,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(untagged)]
pub enum SyncFavoritesPayload {
    List(Vec<i64>),
    Object {
        #[serde(default, alias = "recipe_ids", alias = "recipeIds", alias = "ids")]
        recipe_ids: Vec<i64>,
    },
}

impl SyncFavoritesPayload {
    pub fn into_recipe_ids(self) -> Vec<i64> {
        match self {
            SyncFavoritesPayload::List(ids) => ids,
            SyncFavoritesPayload::Object { recipe_ids } => recipe_ids,
        }
    }
}
