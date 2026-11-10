# Project: BE_Rust (Food Tip System Phase 1 Production Backend)

## Architecture
- Layered Clean Architecture:
  - `src/main.rs`: Application entry point, server startup, router configuration, port binding (default 8787).
  - `src/config.rs`: Environment configuration (PORT, DATABASE_URL, JWT_SECRET, JWT_EXPIRATION).
  - `src/db/`: SQLite connection pool initialization (`SqlitePool`), WAL mode, busy timeout, embedded auto-migrations (`sqlx::migrate!()`).
  - `src/models/`: Domain entities and DTOs with `serde` serialization (camelCase).
  - `src/middleware/`: JWT authentication extractor (`AuthUser`), optional auth extractor (`MaybeAuthUser`), CORS layer, tracing layer, error handling (`AppError`).
  - `src/services/`: Business logic services (AuthService, RecipeService, FavoriteService, PantryService).
  - `src/handlers/`: Axum HTTP request handlers (auth, recipes, catalog, favorites, pantry, health).
  - `tests/`: Integration tests using an in-memory SQLite pool (`sqlite::memory:`).

## Code Layout
- `c:\Users\John Windows\Documents\Code\Dart\mobile\backend\Cargo.toml`
- `c:\Users\John Windows\Documents\Code\Dart\mobile\backend\migrations\`
  - `0001_init.sql`: Table definitions for users, recipes, recipe_nutrition, recipe_instructions, recipe_ingredients, user_favorites, pantry_items.
- `c:\Users\John Windows\Documents\Code\Dart\mobile\backend\src\`
  - `main.rs`
  - `lib.rs`
  - `config.rs`
  - `error.rs`
  - `state.rs`
  - `db/mod.rs`, `db/pool.rs`, `db/seed.rs`
  - `models/mod.rs`, `models/user.rs`, `models/recipe.rs`, `models/favorite.rs`, `models/pantry.rs`
  - `middleware/mod.rs`, `middleware/auth.rs`, `middleware/cors.rs`
  - `services/mod.rs`, `services/auth_service.rs`, `services/recipe_service.rs`, `services/favorite_service.rs`, `services/pantry_service.rs`
  - `handlers/mod.rs`, `handlers/health.rs`, `handlers/auth.rs`, `handlers/recipe.rs`, `handlers/favorite.rs`, `handlers/pantry.rs`
- `c:\Users\John Windows\Documents\Code\Dart\mobile\backend\tests\`
  - `common/mod.rs`: Test helpers, in-memory DB setup, test tokens.
  - `health_and_db_tests.rs`: Milestone M1 tests (Schema, Health, Seed data).
  - `auth_tests.rs`: Milestone M2 tests (Auth, Registration, Login, JWT, Profile).
  - `adversarial_jwt_challenge.rs`: Milestone M2 adversarial security tests.
  - `adversarial_auth_tests.rs`: Milestone M2 boundary & SQL injection tests.
  - `recipe_tests.rs`: Milestone M3 tests (Recipe Catalog, Detail, Search, Suggest).
  - `adversarial_recipe_search_tests.rs`: Milestone M3 adversarial keyword search tests.
  - `adversarial_recipe_ingredient_tests.rs`: Milestone M3 adversarial ingredient scoring tests.
  - `favorite_tests.rs`: Milestone M4 tests (Favorites toggle, get list, sync).
  - `adversarial_favorite_concurrency_tests.rs`: Milestone M4 concurrency tests.
  - `adversarial_favorite_boundary_tests.rs`: Milestone M4 boundary tests.
  - `pantry_tests.rs`: Unit & integration tests for Pantry (R4).
  - `e2e_tests.rs`: End-to-end multi-tier test flows.
- `c:\Users\John Windows\Documents\Code\Dart\mobile\backend\CRATE_EVALUATION.md`: Documentation evaluating all integrated crates against security, performance, and stability (R5).

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Crate Evaluation & Selection | Comprehensive evaluation of 15 Rust crates for security, performance, stability | M1 | R5, Survey 3 |
| 2 | SQLite Schema & Auto-Migrations | Self-contained SQLite database with auto-migration on startup (users, recipes, favorites, pantry) | M1 | R5, Survey 2 & 3 |
| 3 | Database Seeding | Automatic seeding of canonical Vietnamese recipes and units if DB empty | M1 | Survey 1 & 2 |
| 4 | User Registration | POST /api/Account/register (and alias /api/auth/register) with password validation regex | M2 | R1, Survey 1 & 2 |
| 5 | User Login & JWT Issuance | POST /api/Account/login with Argon2/BCrypt verify, issuing HS256 JWT | M2 | R1, Survey 1 & 2 |
| 6 | Get User Profile | GET /api/Account/profile (and alias /api/auth/profile) protected by JWT | M2 | R1, Survey 1 & 2 |
| 7 | Update Profile & Password | PUT /api/Account/update-profile and POST /api/Account/change-password | M2 | Survey 1 & 2 |
| 8 | Recipe Catalog Feed | GET /catalog (and alias /api/Recipes/catalog) returning Spoonacular-compatible JSON array | M3 | R2, Survey 1 |
| 9 | Recipe Summary Listing & Detail | GET /api/Recipes and GET /api/Recipes/{id} | M3 | R2, Survey 1 & 2 |
| 10 | Recipe Keyword Search | GET /api/Recipes/search?term=... | M3 | R2, Survey 2 |
| 11 | Search by Ingredients & Suggest | GET /api/Recipes/search-by-ingredients and POST /suggest | M3 | R2, Survey 1 & 2 |
| 12 | Add / Remove Favorite (Toggle) | POST /api/Recipes/{id}/favorite protected by JWT | M4 | R3, Survey 1 & 2 |
| 13 | Get User Favorites | GET /api/Recipes/favorites protected by JWT | M4 | R3, Survey 1 & 2 |
| 14 | Sync Offline Favorites | POST /api/Recipes/sync-favorites protected by JWT | M4 | R3, Survey 1 & 2 |
| 15 | Get Pantry Ingredients | GET /api/pantry (and alias /api/kitchen-bag) protected by JWT | M5 | R4, Survey 1 |
| 16 | Add Pantry Item | POST /api/pantry (single, flexible name, batch) protected by JWT | M5 | R4, Survey 1 |
| 17 | Update Pantry Item | PUT /api/pantry/{id} protected by JWT | M5 | R4, Survey 1 |
| 18 | Delete Pantry Item / Clear | DELETE /api/pantry/{id} and DELETE /api/pantry protected by JWT | M5 | R4, Survey 1 |
| 19 | E2E Integration Test Suite | Automated test suite verifying 100% of user journeys via `cargo test` | M6 | Acceptance Criteria |
| 20 | Adversarial Hardening & Forensic Audit | Verification against dummy implementations, hardcoded facades, security hardening | M7 | Acceptance Criteria |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Project Setup, SQLite Schema & Crates | Cargo.toml, Crate Evaluation doc, SQLite pool, embedded migrations, initial seed | none | DONE |
| M2 | Auth & User Profile (R1) | Registration, Login, JWT auth middleware, Profile CRUD, Argon2/BCrypt | M1 | DONE |
| M3 | Recipe Catalog & Search (R2) | /catalog feed, /api/Recipes list/detail, search by keyword, ingredient scoring | M1 | DONE |
| M4 | Favorites System (R3) | Add/remove toggle, get favorites, offline sync | M2, M3 | DONE |
| M5 | Pantry / Kitchen Bag Management (R4) | CRUD for pantry items in SQLite, integration with ingredient search | M2 | DONE |
| M6 | Comprehensive Test Suite & Infra | Opaque-box E2E test harness covering Tiers 1-4 (`tests/e2e_tests.rs`) | M1-M5 | DONE |
| M7 | E2E Test Pass & Forensic Hardening | 100% passing cargo test, adversarial Tier 5 tests, Forensic Audit veto check | M6 | DONE |

## Interface Contracts
### Auth (M2) ↔ Downstream (M3, M4, M5)
- Header: `Authorization: Bearer <token>`
- Extractor: `AuthUser(pub Claims)` where `Claims` contains `sub: String` (UserID), `email: String`, `role: String`, `exp: usize`.
- Unauthenticated requests to protected endpoints return HTTP 401 with `{ "message": "...", "error": "Unauthorized" }`.

### Recipe Catalog (M3) ↔ Client & Favorites (M4)
- Recipe ID is `i64`.
- `/catalog` returns JSON array with fields: `id`, `title`, `image`, `source`, `category`, `time`, `servings`, `nutrients`, `steps`, `ingredients`.
- `/api/Recipes/{id}/favorite` toggles favorite in `user_favorites` table and returns `{ "message": "...", "isFavorited": bool }`.

### Pantry (M5) ↔ Search (M3)
- Pantry items belong to `user_id`.
- Ingredients extracted from pantry can feed into `/api/Recipes/search-by-ingredients?ingredients=...` or `/suggest`.
