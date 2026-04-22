from __future__ import annotations

import base64
import binascii
import json
from email.parser import BytesParser
from email.policy import default
from typing import Any

from core import error_payload, normalize_content_type, process_upload


def _lambda_response(payload: dict[str, Any]) -> dict[str, Any]:
    return {
        "statusCode": 200,
        "headers": {
            "content-type": "application/json",
        },
        "body": json.dumps(payload),
    }


def _request_method(event: dict[str, Any]) -> str:
    request_context = event.get("requestContext", {})
    if isinstance(request_context, dict):
        http_context = request_context.get("http", {})
        if isinstance(http_context, dict):
            method = http_context.get("method")
            if isinstance(method, str):
                return method

    method = event.get("httpMethod")
    return method if isinstance(method, str) else ""


def _header_value(headers: object, name: str) -> str:
    if not isinstance(headers, dict):
        return ""
    name_lower = name.lower()
    for key, value in headers.items():
        if (
            isinstance(key, str)
            and key.lower() == name_lower
            and isinstance(value, str)
        ):
            return value
    return ""


def _decode_body(event: dict[str, Any]) -> bytes:
    body = event.get("body", "")
    if not isinstance(body, str):
        raise ValueError("Invalid request body")
    if event.get("isBase64Encoded"):
        try:
            return base64.b64decode(body, validate=True)
        except (binascii.Error, ValueError) as exc:
            raise ValueError("Invalid base64-encoded request body") from exc
    return body.encode("utf-8")


def _parse_multipart_file(
    body: bytes, content_type: str
) -> tuple[bytes | None, str | None]:
    # Strip CRLF from the caller-supplied header value before splicing it into
    # a synthetic MIME envelope; prevents header injection via Content-Type.
    safe_content_type = content_type.replace("\r", "").replace("\n", "")
    message = BytesParser(policy=default).parsebytes(
        f"Content-Type: {safe_content_type}\r\nMIME-Version: 1.0\r\n\r\n".encode(
            "utf-8"
        )
        + body
    )

    if not message.is_multipart():
        return None, None

    for part in message.iter_parts():
        if part.get_content_disposition() != "form-data":
            continue

        field_name = part.get_param("name", header="content-disposition")
        if field_name != "file":
            continue

        return part.get_payload(decode=True) or b"", part.get_content_type()

    return None, None


def handler(event, _context):
    if not isinstance(event, dict):
        return _lambda_response(error_payload("Invalid request event"))

    if _request_method(event) != "POST":
        return _lambda_response(
            error_payload(
                "Use POST to upload a PDF or DOCX as multipart form field 'file'"
            )
        )

    content_type = _header_value(event.get("headers"), "content-type")
    normalized_content_type = normalize_content_type(content_type)
    try:
        body = _decode_body(event)
    except ValueError as exc:
        return _lambda_response(error_payload(str(exc)))

    if normalized_content_type == "multipart/form-data":
        file_bytes, file_content_type = _parse_multipart_file(body, content_type)
        if file_bytes is None:
            return _lambda_response(
                error_payload(
                    "No file provided. Send a PDF or DOCX as multipart form "
                    "field 'file'"
                )
            )
    else:
        file_bytes = body
        file_content_type = content_type

    return _lambda_response(process_upload(file_bytes, file_content_type))
