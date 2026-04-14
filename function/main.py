import functions_framework
import pymupdf
import pymupdf4llm
from flask import jsonify

ALLOWED_CONTENT_TYPES = {
    "application/pdf",
    "application/octet-stream",
}

MAX_FILE_SIZE = 20 * 1024 * 1024  # 20 MB


def _unique_preserving_order(values):
    return list(dict.fromkeys(values))


def _extract_link_targets(doc):
    links = []
    for page in doc:
        for link in page.get_links():
            uri = link.get("uri")
            if uri:
                links.append(uri)
    return _unique_preserving_order(links)


def _render_markdown_output(markdown, links):
    sections = [markdown.rstrip()]

    if links:
        sections.append("## Detected Links\n" + "\n".join(f"- {link}" for link in links))

    return "\n\n".join(section for section in sections if section).rstrip() + "\n"


def _success_response(text):
    return jsonify(
        {
            "status": "success",
            "data": text,
        }
    ), 200


def _error_response(message):
    return jsonify(
        {
            "status": "error",
            "data": message,
        }
    ), 200


@functions_framework.http
def extract_pdf(request):
    if request.method != "POST":
        return _error_response(
            "Use POST to upload a PDF file as multipart form field 'file'"
        )

    file = request.files.get("file")
    if file is None:
        return _error_response(
            "No file provided. Send a PDF as multipart form field 'file'"
        )

    if file.content_type not in ALLOWED_CONTENT_TYPES:
        return _error_response(f"Unsupported content type: {file.content_type}")

    file_bytes = file.read()
    if len(file_bytes) > MAX_FILE_SIZE:
        return _error_response(
            f"File exceeds maximum size of {MAX_FILE_SIZE // (1024 * 1024)} MB"
        )

    if len(file_bytes) == 0:
        return _error_response("Empty file")

    doc = None
    try:
        doc = pymupdf.open(stream=file_bytes, filetype="pdf")
        md_text = pymupdf4llm.to_markdown(doc)
        links = _extract_link_targets(doc)
        response_text = _render_markdown_output(md_text, links)
    except Exception:
        return _error_response("PDF extraction failed")
    finally:
        if doc is not None:
            doc.close()

    return _success_response(response_text)
