"""Photo detection and blur endpoints."""

import os
import uuid
from io import BytesIO
from typing import Optional

import cv2
import numpy as np
from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.responses import Response
from PIL import Image

from ..services.blur_processor import BlurIntensity, BlurStyle, blur_processor
from ..services.face_detector import face_detector

router = APIRouter(prefix="/detect", tags=["photo"])
blur_router = APIRouter(prefix="/blur", tags=["photo"])

# In-memory session store for photo detections
# Maps session_id -> { "image": np.ndarray, "faces": list[dict] }
_photo_sessions: dict[str, dict] = {}


def _cleanup_session(session_id: str):
    """Remove session data."""
    _photo_sessions.pop(session_id, None)


@router.post("/photo")
async def detect_photo(file: UploadFile = File(...)):
    """Detect faces in an uploaded photo.

    Returns:
        JSON with session_id, list of faces with bounding boxes,
        base64 thumbnails, and face IDs.
    """
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=400,
            detail="File must be an image (JPEG, PNG, etc.).",
        )

    try:
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if image is None:
            raise HTTPException(
                status_code=400, detail="Could not decode image."
            )

        # Detect faces
        faces = face_detector.detect_faces(image)

        # Create session
        session_id = str(uuid.uuid4())
        _photo_sessions[session_id] = {
            "image": image,
            "faces": faces,
        }

        # Return faces without embeddings (not needed by client)
        faces_response = [
            {
                "face_id": f["face_id"],
                "bbox": f["bbox"],
                "thumbnail_b64": f["thumbnail_b64"],
            }
            for f in faces
        ]

        return {
            "session_id": session_id,
            "faces": faces_response,
            "face_count": len(faces),
            "image_width": image.shape[1],
            "image_height": image.shape[0],
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Face detection failed: {str(e)}",
        )


@blur_router.post("/photo")
async def blur_photo(
    session_id: str = Form(...),
    face_ids: str = Form(...),
    blur_style: str = Form("gaussian"),
    blur_intensity: str = Form("high"),
):
    """Apply blur to specified faces in a previously detected photo.

    Args:
        session_id: Session ID from /detect/photo response.
        face_ids: Comma-separated list of face IDs to blur.
        blur_style: One of 'gaussian', 'pixelate', 'blackbox'.
        blur_intensity: One of 'low', 'medium', 'high'.

    Returns:
        Blurred image as JPEG binary.
    """
    session = _photo_sessions.get(session_id)
    if not session:
        raise HTTPException(
            status_code=404,
            detail="Session not found. Please detect faces first.",
        )

    try:
        style = BlurStyle(blur_style)
    except ValueError:
        style = BlurStyle.GAUSSIAN

    try:
        intensity = BlurIntensity(blur_intensity)
    except ValueError:
        intensity = BlurIntensity.HIGH

    ids_to_blur = set(face_ids.split(","))

    # Get bboxes for the requested face IDs
    bboxes = [
        f["bbox"]
        for f in session["faces"]
        if f["face_id"] in ids_to_blur
    ]

    if not bboxes:
        raise HTTPException(
            status_code=400,
            detail="No matching face IDs found in session.",
        )

    # Apply blur
    result = blur_processor.blur_faces(
        session["image"], bboxes, style=style, intensity=intensity
    )

    # Encode result as JPEG
    success, buffer = cv2.imencode(
        ".jpg", result, [cv2.IMWRITE_JPEG_QUALITY, 95]
    )
    if not success:
        raise HTTPException(
            status_code=500, detail="Failed to encode result image."
        )

    # Cleanup session after processing
    _cleanup_session(session_id)

    return Response(
        content=buffer.tobytes(),
        media_type="image/jpeg",
        headers={"Content-Disposition": "attachment; filename=blurred.jpg"},
    )
