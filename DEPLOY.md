# Deploying to Azure

Architecture: two independently-scaled VM Scale Sets behind Standard Load Balancers.

```
Internet
   |
   v
Standard LB (public)  --80-->  Frontend VMSS (nginx serves React build, proxies /api/ -> backend LB)
                                     |
                                     v
                      Standard LB (internal, 10.20.2.4) --8000--> Backend VMSS (FastAPI/uvicorn)
                                                                        |
                                                                        v
                                                          Azure Files share "tododata"
                                                          (mounted at /mnt/tododata on every
                                                           backend instance - the JSON "database")
```

Each tier has a separate **build** (CI) and **release** (CD) pipeline. The build pipeline
compiles/packages the code and publishes it as a pipeline artifact. The release pipeline is
triggered by the build pipeline's completion and runs as two stages against two fully separate
infrastructure stacks — **staging first, then production** — uploading the artifact to that
environment's blob storage and redeploying it onto that environment's running VMSS instances.
Production only runs after staging succeeds, gated by an approval check. Each VMSS instance
pulls `latest.zip` from its container via managed identity (using `azcopy login --identity`) — on
first boot (cloud-init) and again whenever the release pipeline calls `az vmss run-command invoke`
after a new upload.

Staging and production are two independent copies of the same Terraform stack (separate resource
groups, VMSS, load balancers, storage accounts — nothing is shared), distinguished by the
`environment` variable. Steps below are written generically as "per environment" — do them once
for staging and once for production.

The infrastructure itself has its own pipeline (`infra-deploy.yml`), separate from the app
build/release pipelines — a Terraform apply can destroy or replace real resources, which is a
different risk class from rolling out new app code and deserves its own plan/review/apply flow
rather than being folded into an app deploy. It follows the same staging-then-production,
approval-gated shape as the app release pipelines, plus a hard split between *plan* (produces a
reviewable diff) and *apply* (applies that exact plan file, never a fresh one) so what gets
approved is what gets applied.

## One-time setup

### 1. Terraform remote state

Create a storage account for state (outside Terraform, since it must exist before `init`). One
state storage account can hold both environments' state files (they use different blob names).

```bash
az group create -n rg-tfstate -l eastus
az storage account create -n sttodotfstate<unique> -g rg-tfstate -l eastus --sku Standard_LRS
az storage container create -n tfstate --account-name sttodotfstate<unique>
```

For each environment, copy the matching example to `infra/terraform/backend.hcl` and fill in the
storage account name — note the `key` differs per environment so state doesn't collide:

- `backend.hcl.staging.example` → `backend.hcl` (key `todoapp-staging.tfstate`)
- `backend.hcl.production.example` → `backend.hcl` (key `todoapp-production.tfstate`)

### 2. terraform.tfvars

For each environment, copy the matching example to `infra/terraform/terraform.tfvars`:

- `terraform.tfvars.staging.example` → `terraform.tfvars`
- `terraform.tfvars.production.example` → `terraform.tfvars`

and set `admin_ssh_public_key` to a real SSH public key (instances have no public IP — access is
via `az vmss run-command invoke` or Azure Bastion, but the scale set resource still requires a
key).

### 3. Provision infrastructure

Run once per environment, with that environment's `backend.hcl` and `terraform.tfvars` in place
(re-running `init -backend-config=backend.hcl -reconfigure` when you switch environments points
Terraform at that environment's state file):

```bash
cd infra/terraform
az login
terraform init -backend-config=backend.hcl -reconfigure
terraform plan -out=tfplan
terraform apply tfplan
```

Note the outputs for each environment — `resource_group_name`, `storage_account_name`,
`frontend_vmss_name`, `backend_vmss_name`, `frontend_url`. Instances will boot with a "waiting for
first release" page since no artifact has been published yet.

This first apply has to be run locally like this, per environment, since it's what creates the
resource group the Azure DevOps service connection (next step) gets scoped to — the infra
pipeline set up in step 8 takes over for *ongoing* changes after that, it can't bootstrap from
nothing unless you instead scope the service connection at the subscription level.

### 4. Azure DevOps service connections

In the Azure DevOps project: **Project Settings > Service connections > New > Azure Resource
Manager**, one scoped to the staging resource group and one scoped to the production resource
group (keeping them separate means a staging deploy can't accidentally touch production). This
step is manual — Terraform's `azurerm` provider can't create Azure DevOps service connections.

### 5. Azure DevOps variable groups

**Pipelines > Library > + Variable group**, create two groups named exactly `todoapp-staging` and
`todoapp-production`. Both pipelines (frontend and backend release) load whichever group matches
the stage they're running, so each group needs all four keys even though a given pipeline only
uses the `frontendVmssName` or `backendVmssName` it needs:

| Variable | Value |
| --- | --- |
| `azureServiceConnection` | that environment's service connection from step 4 |
| `resourceGroupName` | that environment's `terraform output resource_group_name` |
| `storageAccountName` | that environment's `terraform output storage_account_name` |
| `frontendVmssName` | that environment's `terraform output frontend_vmss_name` |
| `backendVmssName` | that environment's `terraform output backend_vmss_name` |

Also grant each service connection's identity **Storage Blob Data Contributor** on its
environment's storage account (so the pipeline can upload releases) — Terraform doesn't know the
service connection's identity, so this role assignment is also manual (`az role assignment
create`).

### 6. Azure DevOps environments and approval gate

Promotion to production requires manual approval, enforced two ways — do both, they're not
redundant:

- **Enforced in YAML, no setup needed.** Each release pipeline's `Production` stage runs a
  `WaitForApproval` job (a `ManualValidation@0` task on the agentless `server` pool) before the
  actual deploy job. This always pauses the run and waits for anyone with pipeline access to
  click Resume — it works out of the box, but it isn't restricted to specific people.
- **RBAC-restricted, requires one-time setup.** **Pipelines > Environments > New environment**,
  create `todoapp-staging` and `todoapp-production` (resource type "None" — these are just
  approval/audit anchors, not Kubernetes/VM resources). On `todoapp-production`, add an
  **Approval check** (Approvals and checks > + > Approvals) naming the specific people/group
  allowed to approve. This is the gate that actually restricts *who* can promote to production —
  set it up before relying on this pipeline for anything real.

### 7. Secure Files for the infra pipeline

The infra pipeline needs the same `terraform.tfvars` / `backend.hcl` content you created locally
in steps 1–2, but it can't read gitignored local files — so upload them as **Secure Files**
instead (Pipelines > Library > Secure files > + Secure file), named exactly:

| Secure file name | Content |
| --- | --- |
| `todoapp-staging.tfvars` | your filled-in `terraform.tfvars.staging.example` |
| `todoapp-staging-backend.hcl` | your filled-in `backend.hcl.staging.example` |
| `todoapp-production.tfvars` | your filled-in `terraform.tfvars.production.example` |
| `todoapp-production-backend.hcl` | your filled-in `backend.hcl.production.example` |

Skip this step if you plan to keep making infra changes via local `terraform apply` and don't
need `infra-deploy.yml`.

### 8. Create the pipelines

Create five pipelines in Azure DevOps, **build pipelines before their release pipeline** — each
release pipeline's `resources.pipelines.source` references its build pipeline by name, so the
build pipeline must already exist under that exact name first. `todoapp-infra-deploy` has no such
dependency and can be created any time after step 7.

| Order | Pipeline name (must match exactly) | YAML file |
| --- | --- | --- |
| 1 | `todoapp-frontend-build` | `pipelines/frontend-build.yml` |
| 2 | `todoapp-frontend-release` | `pipelines/frontend-release.yml` |
| 3 | `todoapp-backend-build` | `pipelines/backend-build.yml` |
| 4 | `todoapp-backend-release` | `pipelines/backend-release.yml` |
| — | `todoapp-infra-deploy` | `pipelines/infra-deploy.yml` |

If you name the build pipelines something other than `todoapp-frontend-build` /
`todoapp-backend-build`, update the `source:` value in the corresponding `*-release.yml` to match.

## Ongoing workflow

Push to `main`:

- Changes under `frontend/` trigger `todoapp-frontend-build`: `npm run build` → zip → publish
  pipeline artifact. Its completion triggers `todoapp-frontend-release`, which deploys to
  **staging** (upload to that environment's `frontend-releases/latest.zip` → `az vmss run-command
  invoke` re-runs `/opt/deploy/deploy-frontend.sh` on every running staging instance), then — after
  the approval check clears — repeats the same steps against **production**.
- Changes under `backend/` trigger `todoapp-backend-build` → `todoapp-backend-release` the same
  way, with `backend-releases/latest.zip` and `deploy-backend.sh`.
- Changes under `infra/terraform/` trigger `todoapp-infra-deploy`: plan and auto-apply against
  **staging**, then plan against **production** and wait for approval before applying. Every
  apply uses the exact plan file its own plan stage produced — nothing gets re-planned right
  before applying.

Scaling out (autoscale or manual) automatically pulls the current `latest.zip` on the new
instance's first boot — no pipeline run needed.

## Known limitations / follow-ups

- **HTTP only.** No TLS. Standard LB is L4 and won't terminate TLS — adding HTTPS later means
  either nginx-terminated certs on the frontend VMs (e.g. via Key Vault-issued certs) or fronting
  the whole thing with Application Gateway.
- **Storage account key in cloud-init and in the Terraform plan artifact.** The Azure Files SMB
  mount credential is embedded in `custom_data` via Terraform (visible to anyone with read access
  to the VMSS resource in the Azure portal/API). Terraform marks this attribute sensitive, so it's
  redacted from `plan`/`apply` console output, but the raw value is still stored inside the
  `tfplan` binary that `infra-deploy.yml` publishes as a pipeline artifact between its plan and
  apply stages (visible to anyone with read access to that pipeline run). Hardening: fetch the key
  from Key Vault at boot using the VMSS's managed identity instead of passing it through Terraform
  variables/custom_data, and/or shorten that pipeline's artifact retention.
- **No SSH/Bastion.** Instance access for debugging is via `az vmss run-command invoke`. Add
  Azure Bastion if interactive shell access is needed.
- **Single region, LRS storage.** No geo-redundancy or multi-region failover.
