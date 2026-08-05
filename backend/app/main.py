import os
import uuid
from datetime import datetime, timezone

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from . import storage
from .models import Todo, TodoCreate, TodoUpdate

app = FastAPI(title="Todo API")

origins = os.environ.get(
    "ALLOWED_ORIGINS", "http://localhost:5173,http://127.0.0.1:5173"
).split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/api/todos", response_model=list[Todo])
def list_todos():
    return storage.read_all()


@app.post("/api/todos", response_model=Todo, status_code=201)
def create_todo(payload: TodoCreate):
    todos = storage.read_all()
    todo = Todo(
        id=str(uuid.uuid4()),
        title=payload.title,
        completed=False,
        created_at=datetime.now(timezone.utc),
    )
    todos.append(todo.model_dump(mode="json"))
    storage.write_all(todos)
    return todo


@app.patch("/api/todos/{todo_id}", response_model=Todo)
def update_todo(todo_id: str, payload: TodoUpdate):
    todos = storage.read_all()
    for todo in todos:
        if todo["id"] == todo_id:
            if payload.title is not None:
                todo["title"] = payload.title
            if payload.completed is not None:
                todo["completed"] = payload.completed
            storage.write_all(todos)
            return todo
    raise HTTPException(status_code=404, detail="Todo not found")


@app.delete("/api/todos/{todo_id}", status_code=204)
def delete_todo(todo_id: str):
    todos = storage.read_all()
    filtered = [todo for todo in todos if todo["id"] != todo_id]
    if len(filtered) == len(todos):
        raise HTTPException(status_code=404, detail="Todo not found")
    storage.write_all(filtered)
