use serde::{Deserialize, Serialize};

/// Entity mapping to `pantry_items` SQLite table
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct PantryItem {
    pub id: i64,
    pub user_id: i64,
    pub name: String,
    pub amount: Option<f64>,
    pub unit: Option<String>,
    pub category: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

/// DTO representing a pantry item in JSON responses
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PantryItemDto {
    pub id: i64,
    pub name: String,
    #[serde(default)]
    pub amount: Option<f64>,
    #[serde(default)]
    pub unit: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub category: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub notes: Option<String>,
    pub created_at: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub updated_at: Option<String>,
}

impl From<PantryItem> for PantryItemDto {
    fn from(item: PantryItem) -> Self {
        Self {
            id: item.id,
            name: item.name,
            amount: item.amount,
            unit: item.unit,
            category: item.category.clone(),
            notes: item.category,
            created_at: item.created_at,
            updated_at: Some(item.updated_at),
        }
    }
}

/// Response returned by GET /api/pantry
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PantryListResponse {
    pub items: Vec<PantryItemDto>,
    pub ingredient_names: Vec<String>,
}

/// Flexible JSON payload for adding pantry item(s)
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct CreatePantryItemRequest {
    #[serde(default, alias = "ingredientName", alias = "ingredient_name")]
    pub name: Option<String>,
    #[serde(default)]
    pub amount: Option<f64>,
    #[serde(default)]
    pub unit: Option<String>,
    #[serde(default)]
    pub notes: Option<String>,
    #[serde(default)]
    pub category: Option<String>,
    #[serde(default, alias = "ingredients", alias = "items")]
    pub names: Option<Vec<String>>,
}

/// Top-level payload for POST /api/pantry (supports single object, raw list of strings, or list of objects)
#[derive(Debug, Clone, Deserialize)]
#[serde(untagged)]
pub enum CreatePantryPayload {
    BatchList(Vec<String>),
    BatchObjects(Vec<CreatePantryItemRequest>),
    Single(CreatePantryItemRequest),
}

impl CreatePantryPayload {
    pub fn into_requests(self) -> Vec<CreatePantryItemRequest> {
        match self {
            CreatePantryPayload::BatchList(names) => names
                .into_iter()
                .map(|n| CreatePantryItemRequest {
                    name: Some(n),
                    amount: Some(1.0),
                    unit: Some(String::new()),
                    ..Default::default()
                })
                .collect(),
            CreatePantryPayload::BatchObjects(reqs) => reqs,
            CreatePantryPayload::Single(req) => {
                if let Some(names) = req.names.as_ref() {
                    names
                        .iter()
                        .map(|n| CreatePantryItemRequest {
                            name: Some(n.clone()),
                            amount: req.amount.or(Some(1.0)),
                            unit: req.unit.clone().or_else(|| Some(String::new())),
                            notes: req.notes.clone(),
                            category: req.category.clone(),
                            names: None,
                        })
                        .collect()
                } else {
                    vec![req]
                }
            }
        }
    }
}

/// Request DTO for PUT /api/pantry/:id
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct UpdatePantryItemRequest {
    pub name: Option<String>,
    pub amount: Option<f64>,
    pub unit: Option<String>,
    #[serde(default)]
    pub notes: Option<String>,
    #[serde(default)]
    pub category: Option<String>,
}

/// Response for POST /api/pantry
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AddPantryResponse {
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub item: Option<PantryItemDto>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub items: Option<Vec<PantryItemDto>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub count: Option<usize>,
}

/// Response for PUT /api/pantry/:id
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdatePantryResponse {
    pub message: String,
    pub item: PantryItemDto,
}

/// Query parameters for DELETE /api/pantry
#[derive(Debug, Clone, Deserialize, Default)]
pub struct DeletePantryQuery {
    pub name: Option<String>,
}
