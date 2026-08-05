import json
import os
import threading
from pathlib import Path
from typing import Any, Dict, List

_DEFAULT_DATA_FILE = Path(__file__).resolve().parent.parent / "data" / "todos.json"
DATA_FILE = Path(os.environ.get("TODO_DATA_FILE", str(_DEFAULT_DATA_FILE)))
_lock = threading.Lock()


def _ensure_file() -> None:
    DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
    if not DATA_FILE.exists():
        DATA_FILE.write_text("[]", encoding="utf-8")


def read_all() -> List[Dict[str, Any]]:
    _ensure_file()
    with _lock:
        return json.loads(DATA_FILE.read_text(encoding="utf-8"))


def write_all(todos: List[Dict[str, Any]]) -> None:
    _ensure_file()
    with _lock:
        DATA_FILE.write_text(json.dumps(todos, indent=2, default=str), encoding="utf-8")
