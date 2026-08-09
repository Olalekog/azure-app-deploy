from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_todo_crud_lifecycle():
    create_response = client.post("/api/todos", json={"title": "Buy milk"})
    assert create_response.status_code == 201
    todo = create_response.json()
    assert todo["title"] == "Buy milk"
    assert todo["completed"] is False

    list_response = client.get("/api/todos")
    assert list_response.status_code == 200
    assert any(t["id"] == todo["id"] for t in list_response.json())

    patch_response = client.patch(f"/api/todos/{todo['id']}", json={"completed": True})
    assert patch_response.status_code == 200
    assert patch_response.json()["completed"] is True

    rename_response = client.patch(f"/api/todos/{todo['id']}", json={"title": "Buy oat milk"})
    assert rename_response.status_code == 200
    assert rename_response.json()["title"] == "Buy oat milk"

    delete_response = client.delete(f"/api/todos/{todo['id']}")
    assert delete_response.status_code == 204

    final_list = client.get("/api/todos").json()
    assert all(t["id"] != todo["id"] for t in final_list)


def test_create_rejects_empty_title():
    response = client.post("/api/todos", json={"title": ""})
    assert response.status_code == 422


def test_update_missing_todo_returns_404():
    response = client.patch("/api/todos/does-not-exist", json={"completed": True})
    assert response.status_code == 404


def test_delete_missing_todo_returns_404():
    response = client.delete("/api/todos/does-not-exist")
    assert response.status_code == 404
