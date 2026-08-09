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

Staging and production are two independent applies of the same Terraform stack, distinguished by
the `environment` variable — but in this deployment both share **one pre-existing resource group,
one pre-existing storage account, and one pre-existing VNet** (a training-subscription
constraint: no permission to create new resource groups, storage accounts, or VNets). Terraform
reads all three as data sources rather than creating them. Everything that *is* Terraform-managed
(subnets, NSGs, LBs, VMSS, the Azure Files share, the release blob containers) is named — and, for
subnets, address-ranged — per environment so staging and production never collide inside that
shared VNet/account/RG — e.g. `vmss-frontend-todoapp-staging` vs `vmss-frontend-todoapp-production`,
`frontend-releases-staging` vs `frontend-releases-production`, and non-overlapping subnet CIDRs
carved out of the shared VNet's address space. Steps below are written generically as "per
environment" — do them once for staging and once for production.

Subscription: **AzureTraining**. Resource group: **Training-Batch-6.23**. Storage account:
**olalekog**. VNet: **VM-VNET**. Azure DevOps project:
**[training-proj](https://dev.azure.com/324DSTraining/training-proj)** (org `324DSTraining`). Run
`az account set --subscription "AzureTraining"` before any local `az`/`terraform` command —
everything below assumes that context is already selected.

The infrastructure itself has its own pipeline (`infra-deploy.yml`), separate from the app
build/release pipelines — a Terraform apply can destroy or replace real resources, which is a
different risk class from rolling out new app code and deserves its own plan/review/apply flow
rather than being folded into an app deploy. It follows the same staging-then-production,
approval-gated shape as the app release pipelines, plus a hard split between *plan* (produces a
reviewable diff) and *apply* (applies that exact plan file, never a fresh one) so what gets
approved is what gets applied.

## One-time setup

### 1. Terraform remote state

State lives in the existing storage account, in its own container — this only needs a container
created within the account you already have, not a new resource group or storage account:

```bash
az storage container create -n tfstate --account-name olalekog
```

For each environment, copy the matching example to `infra/terraform/backend.hcl` — both already
point at `Training-Batch-6.23` / `olalekog`, only the `key` differs per environment so state
doesn't collide:

- `backend.hcl.staging.example` → `backend.hcl` (key `todoapp-staging.tfstate`)
- `backend.hcl.production.example` → `backend.hcl` (key `todoapp-production.tfstate`)

### 2. terraform.tfvars

For each environment, copy the matching example to `infra/terraform/terraform.tfvars`:

- `terraform.tfvars.staging.example` → `terraform.tfvars`
- `terraform.tfvars.production.example` → `terraform.tfvars`

Both already set `existing_resource_group_name = "Training-Batch-6.23"`,
`existing_storage_account_name = "olalekog"`, and `existing_vnet_name = "VM-VNET"` — but you still
need to fill in `frontend_subnet_prefix`, `backend_subnet_prefix`, and `backend_lb_private_ip` in
**both** files with real, non-overlapping CIDRs (there are no defaults for these on purpose, since
guessing wrong here fails the apply or, worse, silently collides with something already in
VM-VNET). Check the VNet's actual address space first:

```bash
az network vnet show --name VM-VNET -g Training-Batch-6.23 --query addressSpace -o jsonc
```

then pick two /24s (or whatever size you need) per environment that fit inside it and don't
overlap each other — staging and production share this one VNet now, unlike the resource group
and storage account where per-environment names are always in different sub-resources. Also set
`admin_ssh_public_key` to a real SSH public key (instances have no public IP — access is via
`az vmss run-command invoke` or Azure Bastion, but the scale set resource still requires a key).

### 3. Provision infrastructure

Run once per environment, with that environment's `backend.hcl` and `terraform.tfvars` in place
(re-running `init -backend-config=backend.hcl -reconfigure` when you switch environments points
Terraform at that environment's state file):

```bash
cd infra/terraform
az account set --subscription "AzureTraining"
terraform init -backend-config=backend.hcl -reconfigure
terraform plan -out=tfplan
terraform apply tfplan
```

Note the outputs for each environment — `resource_group_name`, `storage_account_name`,
`frontend_vmss_name`, `backend_vmss_name`, `frontend_release_container`,
`backend_release_container`, `frontend_url`. Instances will boot with a "waiting for first
release" page since no artifact has been published yet.

Since the resource group and storage account already exist, there's no bootstrap ordering problem
here — the Azure DevOps service connection (next step) can be scoped to `Training-Batch-6.23`
before or after this first apply, and the infra pipeline (step 8) is equally capable of running
this first apply itself instead of doing it locally.

### 4. Azure DevOps service connection

In the Azure DevOps project: **Project Settings > Service connections > New > Azure Resource
Manager**, named exactly `AzureTraining`, pointed at subscription **AzureTraining**
(`606e824b-aaf7-4b4e-9057-b459f6a4436d`), scoped down to the `Training-Batch-6.23` resource group.
This step stays manual — creating trust/credential objects like a service connection is
deliberately left out of Terraform here, unlike the variable groups and secret in the next step.
One connection is enough for both environments, since staging and production already share this
resource group — there's no RG-level isolation to preserve by creating two.

You'll need this connection's underlying service principal's Entra ID **object ID** for step 5 —
find it via **Manage Service Principal** on the connection's detail page (opens the Entra portal
to its App ID), then:

```bash
az ad sp show --id <appId> --query id -o tsv
```

### 5. Library variable groups and secrets (Terraform-managed)

Everything under **Pipelines > Library** — the `todoapp-staging` / `todoapp-production` variable
groups, a new Key Vault, the `azureServiceConnection` secret in it, and the Key Vault-linked
`todoapp-azure-connection` group exposing that secret — is created by a third Terraform stack,
[infra/terraform-devops/](infra/terraform-devops/), rather than by hand. It reads its values out
of the staging and production app infra's remote state, so **both environments from step 3 must
already be applied** before this stack can be.

```bash
cd infra/terraform-devops
cp terraform.tfvars.example terraform.tfvars   # already has azdo_project_name = "training-proj" -
                                                # fill in key_vault_name (must be globally unique)
                                                # and azure_training_sp_object_id (from step 4)
cp backend.hcl.example backend.hcl             # already points at Training-Batch-6.23 / olalekog

export AZDO_ORG_SERVICE_URL="https://dev.azure.com/324DSTraining"
export AZDO_PERSONAL_ACCESS_TOKEN="<PAT with Variable Groups read/create/manage scope>"

terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
```

What this creates, all named to match what the pipelines already expect (see
[pipelines/frontend-release.yml](pipelines/frontend-release.yml)'s header for the full list each
group needs):

- `todoapp-staging` / `todoapp-production` — plain variable groups holding
  `resourceGroupName`, `storageAccountName`, `frontendVmssName`, `backendVmssName`,
  `frontendReleaseContainer`, `backendReleaseContainer`, pulled straight from
  `terraform output` in each environment's app infra state.
- A new Key Vault (`key_vault_name`, RBAC-authorized, in `Training-Batch-6.23` by default)
  holding two secrets: `azureServiceConnection` (value `AzureTraining`) and
  `azureTrainingSpObjectId` (value `azure_training_sp_object_id` from your tfvars — persisted
  here so nothing downstream has to re-discover that GUID by hand) — plus a **Key Vault Secrets
  User** role assignment so Azure DevOps can actually read them. Since the vault uses RBAC
  authorization, the identity running `terraform apply` also needs a **Key Vault Secrets
  Officer** grant on it to write those secrets in the same apply — the stack creates that
  role assignment itself and pauses 30s for it to propagate before writing them, so this
  should just work, but if the very first apply 403s on a secret, it's this propagation delay
  and a second `terraform apply` will succeed. Note `azure_training_sp_object_id` itself can't
  come *from* this vault — it's what grants access to the vault in the first place, so it has to
  stay a plain Terraform input.
- `todoapp-azure-connection` — the Key Vault-linked variable group exposing both secrets as
  Library variables (`azureServiceConnection`, `azureTrainingSpObjectId`). Shared by both
  environments since neither value differs between them.
- **Storage Blob Data Contributor** on the `AzureTraining` connection's identity, scoped to each
  environment's two release containers specifically — not the whole shared account, since it
  likely holds other people's training data too.

Note the self-reference: the `AzureTraining` connection both authorizes the Key Vault link *and*
is the value the resulting variable resolves to. Those are two independent uses of it (one is
"can Azure DevOps read this vault," the other is "which subscription should `az`/`terraform`
commands run against"), so there's no actual circularity — just re-use of the same connection.

The PAT and org URL only need to be exported in your shell for this one apply — nothing in this
repo stores them.

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
  **staging** (upload to that environment's `frontend-releases-staging/latest.zip` →
  `az vmss run-command invoke` re-runs `/opt/deploy/deploy-frontend.sh` on every running staging
  instance), then — after the approval check clears — repeats the same steps against
  **production** (`frontend-releases-production/latest.zip`).
- Changes under `backend/` trigger `todoapp-backend-build` → `todoapp-backend-release` the same
  way, with `backend-releases-staging` / `backend-releases-production` and `deploy-backend.sh`.
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
- **Single region, LRS storage.** No geo-redundancy or multi-region failover. Region is whatever
  `Training-Batch-6.23` is deployed in — not independently configurable, since resources now
  inherit the existing resource group's location instead of a `location` variable.
- **Shared resource group, storage account, and VNet.** Staging and production — and possibly
  other people's training exercises — live in the same `Training-Batch-6.23` RG, `olalekog`
  account, and `VM-VNET`. Role assignments for both the VMSS managed identities and the pipeline
  service connection are scoped down to each environment's specific release container, not the
  whole account, but that only protects blob data — NSGs and everything else Terraform creates
  still share the RG's blast radius with whatever else is in it (e.g. a broad `az role assignment`
  or resource deletion by someone else in the RG isn't isolated from this app). Not something to
  fix in Terraform; just a real constraint of building on shared training infrastructure instead
  of dedicated resource groups/VNets per environment.
- **No network-level isolation from other things in VM-VNET.** Subnets are per-environment and
  NSG'd, but since it's a shared VNet rather than a dedicated one, anything else already deployed
  there (or added later by someone else) is in the same routing domain unless VM-VNET has its own
  additional segmentation. The NSGs here only control what reaches *this app's* subnets, not what
  those subnets could reach elsewhere in VM-VNET.
