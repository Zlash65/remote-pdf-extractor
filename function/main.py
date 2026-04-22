"""Platform entrypoint router.

GCP Cloud Functions' Python runtime requires `main.py`, so both platform
handlers are re-exported here for a single, uniform deploy artifact.
"""

from aws_handler import handler  # noqa: F401
from gcp_handler import extract_document  # noqa: F401
