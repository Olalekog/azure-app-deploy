import os
import tempfile

# Must run before `app.storage` is imported anywhere, since it reads this env var at
# import time - point tests at a throwaway file instead of the real dev data file.
os.environ["TODO_DATA_FILE"] = os.path.join(tempfile.mkdtemp(), "todos.json")
