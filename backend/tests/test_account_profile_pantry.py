def test_register_returns_token_and_never_password(client):
    response = client.post(
        "/api/Account/register",
        json={"username": "An_Nguyen", "email": "AN@Example.com", "password": "matkhau123", "displayName": "An"},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["token"]
    assert body["username"] == "an_nguyen"
    assert body["email"] == "an@example.com"
    assert body["displayName"] == "An"
    assert "password" not in body and "passwordHash" not in body


def test_register_rejects_duplicates_case_insensitively(client, register):
    register("an_nguyen")
    response = client.post(
        "/api/Account/register",
        json={"username": "AN_NGUYEN", "email": "other@example.com", "password": "matkhau123"},
    )
    assert response.status_code == 409
    assert response.json()["message"]


def test_login_by_username_or_email(client, register):
    register("an_nguyen")
    for identifier in ("an_nguyen", "AN_NGUYEN", "an_nguyen@example.com"):
        response = client.post(
            "/api/Account/login",
            json={"usernameOrEmail": identifier, "password": "matkhau123", "rememberMe": True},
        )
        assert response.status_code == 200, identifier
        assert response.json()["token"]


def test_login_failure_does_not_reveal_which_part_is_wrong(client, register):
    register("an_nguyen")
    wrong_password = client.post("/api/Account/login", json={"usernameOrEmail": "an_nguyen", "password": "sai-mat-khau"})
    unknown_user = client.post("/api/Account/login", json={"usernameOrEmail": "khong_co", "password": "sai-mat-khau"})
    assert wrong_password.status_code == unknown_user.status_code == 401
    assert wrong_password.json() == unknown_user.json()


def test_validation_error_does_not_echo_password(client):
    secret = "abc"
    response = client.post(
        "/api/Account/register", json={"username": "an_nguyen", "email": "a@example.com", "password": secret}
    )
    assert response.status_code == 422
    assert response.json()["message"]
    assert all("input" not in e for e in response.json()["errors"])
    assert f'"{secret}"' not in response.text


def test_protected_routes_require_valid_token(client):
    bad = {"Authorization": "Bearer khong-hop-le"}
    for path in ("/api/Profile", "/api/Pantry", "/api/Recipes/favorites"):
        assert client.get(path).status_code == 401, path
        assert client.get(path, headers=bad).status_code == 401, path


def test_profile_update_only_changes_allowed_fields(client, register):
    headers = register()
    response = client.put(
        "/api/Profile",
        headers=headers,
        json={"displayName": "Đầu Bếp An", "dietPreference": "Keto / Low-Carb", "role": "Admin", "isPro": True},
    )
    assert response.status_code == 200
    body = client.get("/api/Profile", headers=headers).json()
    assert body["displayName"] == "Đầu Bếp An"
    assert body["dietPreference"] == "Keto / Low-Carb"
    assert body["bio"] == ""
    assert body["role"] == "Member"
    assert body["isPro"] is False


def test_profile_false_value_is_applied(client, register):
    headers = register()
    client.put("/api/Profile", headers=headers, json={"notificationEnabled": False})
    assert client.get("/api/Profile", headers=headers).json()["notificationEnabled"] is False


def test_pantry_add_dedupes_remove_and_clear(client, register):
    headers = register()
    client.post("/api/Pantry", headers=headers, json={"name": "Thịt bò"})
    assert client.post("/api/Pantry", headers=headers, json={"name": "  THỊT BÒ "}).json() == ["Thịt bò"]
    assert client.post("/api/Pantry", headers=headers, json={"name": "Trứng"}).json() == ["Thịt bò", "Trứng"]
    assert client.delete("/api/Pantry/thịt bò", headers=headers).json() == ["Trứng"]
    assert client.delete("/api/Pantry", headers=headers).json() == []
    assert client.post("/api/Pantry", headers=headers, json={"name": "   "}).status_code == 422


def test_pantry_is_private_per_user(client, register):
    an, binh = register("an_nguyen"), register("binh_tran")
    client.post("/api/Pantry", headers=an, json={"name": "Thịt bò"})
    assert client.get("/api/Pantry", headers=binh).json() == []
    client.delete("/api/Pantry", headers=binh)
    assert client.get("/api/Pantry", headers=an).json() == ["Thịt bò"]
