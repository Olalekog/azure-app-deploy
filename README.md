# azure-app-deploy

A 3-tier To-Do app:

- **Frontend** — React (Vite) — [frontend/](frontend/)
- **Backend** — FastAPI (REST API) — [backend/](backend/)
- **Data tier** — JSON file on disk (no SQL database) — [backend/data/todos.json](backend/data/todos.json)

## Run the backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate       # Windows
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

API docs available at http://localhost:8000/docs

## Run the frontend

```bash
cd frontend
npm install
npm run dev
```

App available at http://localhost:5173 — the Vite dev server proxies `/api` requests to the backend on port 8000.

## Deploying to Azure

Terraform provisions two VM Scale Sets (frontend/backend) behind Standard Load Balancers, with
an Azure Files share as the shared JSON data tier. Azure DevOps Pipelines build and release each
tier independently. See [DEPLOY.md](DEPLOY.md) for the full architecture and setup steps.

- App infrastructure — [infra/terraform/](infra/terraform/)
- Azure DevOps library variables/secrets — [infra/terraform-devops/](infra/terraform-devops/)
- Pipelines — [pipelines/](pipelines/)
