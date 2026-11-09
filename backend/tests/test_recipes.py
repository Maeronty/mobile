import unicodedata


def test_seed_loads_all_recipes_with_details(client):
    recipes = client.get("/api/Recipes").json()
    assert len(recipes) == 10
    pho = recipes[0]
    assert pho["title"] == "Phở Bò Tái Lăn Hà Nội"
    assert pho["imageUrl"] == pho["imageAsset"] == "assets/images/pho.png"
    assert pho["nutrition"]["proteinGrams"] == 32
    assert [i["name"] for i in pho["ingredients"]][0] == "Bánh phở tươi"
    assert [s["stepNumber"] for s in pho["instructions"]] == [1, 2, 3, 4]
    assert pho["isFavorited"] is False


def test_seed_does_not_duplicate_on_restart(client):
    from app.main import app
    from fastapi.testclient import TestClient

    with TestClient(app):
        pass
    assert len(client.get("/api/Recipes").json()) == 10


def test_detail_and_not_found(client):
    assert client.get("/api/Recipes/3").json()["id"] == 3
    response = client.get("/api/Recipes/999")
    assert response.status_code == 404
    assert "999" in response.json()["message"]


def test_search_by_title_category_tag_case_insensitive(client):
    assert [r["id"] for r in client.get("/api/Recipes/search", params={"term": "PHỞ"}).json()] == [1]
    assert {r["id"] for r in client.get("/api/Recipes/search", params={"term": "healthy"}).json()} == {5, 7}
    assert 8 in {r["id"] for r in client.get("/api/Recipes/search", params={"term": "keto"}).json()}
    assert client.get("/api/Recipes/search", params={"term": "khongcomon"}).json() == []


def test_search_matches_decomposed_unicode(client):
    decomposed = unicodedata.normalize("NFD", "Phở")
    assert decomposed != "Phở"
    assert [r["id"] for r in client.get("/api/Recipes/search", params={"term": decomposed}).json()] == [1]


def test_match_score_same_algorithm_as_app(client):
    results = client.get("/api/Recipes/search-by-ingredients", params={"ingredients": "Thịt bò, Bánh phở"}).json()
    pho = next(r for r in results if r["id"] == 1)
    assert pho["matchedIngredients"] == ["Bánh phở tươi", "Thịt bò thăn"]
    assert pho["matchScore"] == 2 / 6
    assert "Nước hầm xương bò" in pho["missingIngredients"]
    assert len(pho["matchedIngredients"]) + len(pho["missingIngredients"]) == len(pho["ingredients"])
    scores = [r["matchScore"] for r in results]
    assert scores == sorted(scores, reverse=True)
    assert all(r["matchScore"] > 0 for r in results)


def test_match_blank_input_does_not_match_everything(client):
    assert client.get("/api/Recipes/search-by-ingredients", params={"ingredients": " , ,"}).json() == []


def test_favorite_toggle_requires_login_and_is_per_user(client, register):
    assert client.post("/api/Recipes/1/favorite").status_code == 401
    an, binh = register("an_nguyen"), register("binh_tran")

    assert client.post("/api/Recipes/1/favorite", headers=an).json() == {"isFavorited": True}
    assert client.get("/api/Recipes/favorites", headers=an).json() == [1]
    assert client.get("/api/Recipes/1", headers=an).json()["isFavorited"] is True
    assert client.get("/api/Recipes/1", headers=binh).json()["isFavorited"] is False
    assert client.get("/api/Recipes/1").json()["isFavorited"] is False
    assert client.get("/api/Profile", headers=an).json()["savedRecipesCount"] == 1

    assert client.post("/api/Recipes/1/favorite", headers=an).json() == {"isFavorited": False}
    assert client.get("/api/Recipes/favorites", headers=an).json() == []
    assert client.post("/api/Recipes/999/favorite", headers=an).status_code == 404


def test_expired_or_bad_token_still_allows_public_browsing(client):
    response = client.get("/api/Recipes/1", headers={"Authorization": "Bearer het-han"})
    assert response.status_code == 200
    assert response.json()["isFavorited"] is False


def test_ingredient_names_sorted_unique(client):
    names = client.get("/api/Recipes/ingredients").json()
    assert "Thịt bò thăn" in names
    assert names == sorted(set(names))


def test_swagger_available_at_path_app_pings(client):
    assert client.get("/swagger/index.html").status_code == 200
    assert client.get("/health").json() == {"status": "ok", "aiEnabled": False}
