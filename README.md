# PDF Extractor

Private Google Cloud Function (2nd gen) that accepts a PDF upload and returns Markdown extracted with `pymupdf4llm`.

The response appends a `Detected Links` section when the PDF contains link targets.

## Repo layout

- `function/`: Cloud Function source
- `terraform/`: deployment infrastructure

## Request and response

Request:

- method: `POST`
- content type: `multipart/form-data`
- file field: `file`
- max file size: `20 MB`

Success:

```json
{
  "status": "success",
  "data": "# Extracted markdown..."
}
```

Handled failure:

```json
{
  "status": "error",
  "data": "PDF extraction failed"
}
```

Notes:

- application-level success and failure both return HTTP `200`
- `401` or `403` usually means Google auth or IAM blocked the request before the handler ran

## Deploy

### Prerequisites

- a GCP project with billing enabled
- these project APIs available before the first apply:
  - `cloudresourcemanager.googleapis.com`
  - `iam.googleapis.com`
  - `serviceusage.googleapis.com`
  - `storage.googleapis.com`
- Terraform will enable these runtime APIs during deploy:
  - `cloudfunctions.googleapis.com`
  - `cloudbuild.googleapis.com`
  - `run.googleapis.com`
  - `artifactregistry.googleapis.com`

### Service accounts

Create two service accounts:

1. Deployer
   Use this for Terraform.

   Required project roles:
   - `Cloud Functions Admin`
   - `Cloud Run Admin`
   - `Cloud Build Editor`
   - `Storage Admin`
   - `Service Account Admin`
   - `Service Usage Admin`

   Store its JSON key in the Terraform Cloud environment variable `GOOGLE_CREDENTIALS`.

2. Caller
   Use this from your backend or local authenticated tests.

   Do not grant broad project roles. Terraform grants this identity `roles/run.invoker` on the function through `invoker_members`.

### Terraform Cloud

Before the first remote run:

1. Check [terraform/backends.tf](/Users/zlash/startup/recruitment-pipeline/candidate-dex/reydex-pdf-extractor/terraform/backends.tf:1)
   Change the backend organization if you are not using `core-services`.
2. Create a workspace such as `pdf-extractor-dev`, `pdf-extractor-staging`, or `pdf-extractor-prod`
3. Set the working directory to `terraform/`

Required Terraform variables:

| Variable | Example |
|---|---|
| `gcp_project_id` | `my-project-id` |
| `terraform_runner_member` | `serviceAccount:pdf-extractor-deployer@my-project-id.iam.gserviceaccount.com` |
| `invoker_members` | `["serviceAccount:pdf-extractor-caller@my-project-id.iam.gserviceaccount.com"]` |

Optional Terraform variables:

| Variable | Default |
|---|---|
| `gcp_region` | `us-central1` |
| `resource_name_prefix` | derived from workspace name, or `pdf-extractor` |
| `environment` | derived from workspace name, or `shared` |
| `max_instance_count` | `10` |
| `min_instance_count` | `0` |
| `available_memory` | `512Mi` |
| `available_cpu` | `1` |
| `timeout_seconds` | `120` |

Required Terraform Cloud environment variable:

| Variable | Value |
|---|---|
| `GOOGLE_CREDENTIALS` | full JSON contents of the deployer service-account key |

`resource_name_prefix` is mainly useful for local CLI runs or when you want to pin resource names explicitly.

### Apply

CLI:

```bash
cd terraform
terraform init
terraform workspace select -or-create dev
terraform apply
```

VCS-driven remote runs also work, but the repo checkout must include both `terraform/` and `function/`.

After apply, save the output:

```text
function_url = "https://..."
```

Your callers use that URL as both:

- the request URL
- the ID-token audience

## Invoke

Set:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/pdf-extractor-caller.json
export FUNCTION_URL="https://YOUR_FUNCTION_URL"
```

### Python

```python
import os

import google.auth.transport.requests
import google.oauth2.id_token
import httpx


function_url = os.environ["FUNCTION_URL"]
token = google.oauth2.id_token.fetch_id_token(
    google.auth.transport.requests.Request(),
    function_url,
)

response = httpx.post(
    function_url,
    files={"file": ("document.pdf", open("document.pdf", "rb").read(), "application/pdf")},
    headers={"Authorization": f"Bearer {token}"},
    timeout=120,
)
response.raise_for_status()
payload = response.json()
print(payload)
```

### curl

```bash
TOKEN="$(python - <<'PY'
import os
import google.auth.transport.requests
import google.oauth2.id_token

request = google.auth.transport.requests.Request()
print(google.oauth2.id_token.fetch_id_token(request, os.environ["FUNCTION_URL"]))
PY
)"

curl -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -F "file=@document.pdf" \
  "${FUNCTION_URL}"
```

## Local parser-only run

This bypasses Google IAM and only tests the function handler locally.

```bash
cd function
pip install -r requirements.txt
functions-framework --target=extract_pdf --port=8080
```

Then:

```bash
curl -X POST -F "file=@test.pdf" http://localhost:8080
```

## Notes

- keep `function/requirements.txt` inside `function/`; Terraform uploads that directory as the function source root
- the local helper script `call_extractor.py` expects `FUNCTION_URL` to be set for remote mode

## License

AGPL-3.0. See the upstream [pymupdf4llm license](https://github.com/pymupdf/pymupdf4llm/blob/main/LICENSE).
