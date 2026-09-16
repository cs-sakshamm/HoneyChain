"""
QR Code generation service for HoneyChain batches.
Generates base64 data URIs and public verification URLs.
"""
from __future__ import annotations

import base64
import io
import os
import qrcode

BASE_URL = os.getenv("PUBLIC_APP_URL", "http://127.0.0.1:8000")


def generate_qr_data_uri(batch_id: str) -> tuple[str, str]:
    """
    Returns (verification_url, data_uri)
    """
    base_url = os.getenv("PUBLIC_APP_URL", BASE_URL).rstrip("/")
    verification_url = f"{base_url}/verify/{batch_id}"
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=8,
        border=3,
    )
    qr.add_data(verification_url)
    qr.make(fit=True)

    img = qr.make_image(fill_color="black", back_color="white")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode("utf-8")
    data_uri = f"data:image/png;base64,{b64}"

    return verification_url, data_uri
