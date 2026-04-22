# Function Packages

Run this before Terraform whenever `function/` or `function/requirements.txt` changes:

```bash
./scripts/build-function-zip.sh
```

For AWS, override the package target when Terraform variables change:

```bash
AWS_PYTHON_RUNTIME=python3.13 LAMBDA_ARCHITECTURE=arm64 ./scripts/build-function-zip.sh
```

The script writes the committed deployment artifacts used by Terraform:

- `aws-lambda.zip` keeps handler source files at the archive root and installs Lambda dependencies under `_deps/`.
- `gcp-cloud-function.zip` keeps handler source files at the archive root and downloads copied pip dependencies under `_vendor/`.

`scripts/build-function-zip.sh` handles shell orchestration; `scripts/package_archive.py` creates deterministic zip files.
