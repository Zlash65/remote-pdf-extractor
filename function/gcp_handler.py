from __future__ import annotations

import functions_framework
from core import error_payload, process_upload
from flask import jsonify


@functions_framework.http
def extract_document(request):
    if request.method != "POST":
        return jsonify(
            error_payload(
                "Use POST to upload a PDF or DOCX as multipart form field 'file'"
            )
        )

    uploaded_file = request.files.get("file")
    if uploaded_file is None:
        return jsonify(
            error_payload(
                "No file provided. Send a PDF or DOCX as multipart form field 'file'"
            )
        )

    return jsonify(process_upload(uploaded_file.read(), uploaded_file.content_type))
