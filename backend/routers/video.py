"""Video detection and blur endpoints."""

import os
import shutil
import subprocess
import tempfile
import uuid
from typing import Optional

import cv2
import numpy as np
from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse

from ..services.blur_processor import BlurIntensity, BlurStyle, blur_processor
from ..services.face_clusterer import face_clusterer
from ..services.face_detector import face_detector

router = APIRouter(prefix="/detect", tags=["video"])
blur_router = APIRouter(prefix="/blur", tags=["video"])

# In-memory session store for video processing
# Maps session_id -> { "video_path": str, "persons": list, "frame_detections": list, ... }
_video_sessions: dict[str, dict] = {}

# Temp directory for video files
TEMP_DIR = tempfile.mkdtemp(prefix="faceshield_")

# Max video duration in seconds (5 minutes)
MAX_DURATION_SEC = 300

# Frame sampling rate for detection (process every Nth frame)
DETECTION_FRAME_INTERVAL = 5


def _cleanup_session_files(session_id: str):
    """Remove all temp files for a session."""
    session = _video_sessions.pop(session_id, None)
    if session:
        for key in ["video_path", "output_path"]:
            path = session.get(key)
            if path and os.path.exists(path):
                try:
                    os.remove(path)
                except OSError:
                    pass


@router.post("/video")
async def detect_video(file: UploadFile = File(...)):
    """Detect and cluster faces across a video.

    Processes the video frame-by-frame, detects faces, generates
    embeddings, and clusters them into unique persons.

    Returns:
        JSON with session_id, list of unique persons with sample
        thumbnails and frame timestamps.
    """
    if not file.content_type or not file.content_type.startswith("video/"):
        raise HTTPException(
            status_code=400,
            detail="File must be a video (MP4, MOV, etc.).",
        )

    session_id = str(uuid.uuid4())
    video_path = os.path.join(TEMP_DIR, f"{session_id}_input.mp4")

    try:
        # Save uploaded video to temp file
        contents = await file.read()
        with open(video_path, "wb") as f:
            f.write(contents)

        # Open video
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            raise HTTPException(
                status_code=400, detail="Could not open video file."
            )

        fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        duration = total_frames / fps

        if duration > MAX_DURATION_SEC:
            cap.release()
            os.remove(video_path)
            raise HTTPException(
                status_code=400,
                detail=f"Video too long ({duration:.0f}s). Maximum is {MAX_DURATION_SEC}s (5 minutes).",
            )

        # Process frames for face detection
        all_detections = []
        frame_index = 0

        while True:
            ret, frame = cap.read()
            if not ret:
                break

            if frame_index % DETECTION_FRAME_INTERVAL == 0:
                timestamp = frame_index / fps
                faces = face_detector.detect_faces(frame)

                for face in faces:
                    face["frame_index"] = frame_index
                    face["timestamp"] = timestamp

                all_detections.extend(faces)

            frame_index += 1

        cap.release()

        # Cluster faces into unique persons
        persons = face_clusterer.cluster_faces(all_detections)

        # Build face_id -> person_id mapping
        face_id_to_person = {}
        for person in persons:
            for fid in person["face_ids"]:
                face_id_to_person[fid] = person["person_id"]

        # Store session data
        _video_sessions[session_id] = {
            "video_path": video_path,
            "persons": persons,
            "all_detections": all_detections,
            "face_id_to_person": face_id_to_person,
            "fps": fps,
            "total_frames": total_frames,
        }

        # Format response (exclude embeddings and internal data)
        persons_response = [
            {
                "person_id": p["person_id"],
                "label": p["label"],
                "sample_thumbnail_b64": p["sample_thumbnail_b64"],
                "appearance_count": len(p["face_ids"]),
                "frame_timestamps": p["frame_timestamps"][:10],
            }
            for p in persons
        ]

        return {
            "session_id": session_id,
            "persons": persons_response,
            "person_count": len(persons),
            "video_duration": duration,
            "total_frames_analyzed": frame_index,
        }

    except HTTPException:
        raise
    except Exception as e:
        # Cleanup on error
        if os.path.exists(video_path):
            os.remove(video_path)
        raise HTTPException(
            status_code=500,
            detail=f"Video processing failed: {str(e)}",
        )


@blur_router.post("/video")
async def blur_video(
    session_id: str = Form(...),
    person_ids: str = Form(...),
    blur_style: str = Form("gaussian"),
    blur_intensity: str = Form("high"),
):
    """Apply blur to specified persons across all video frames.

    Args:
        session_id: Session ID from /detect/video response.
        person_ids: Comma-separated list of person IDs to blur.
        blur_style: One of 'gaussian', 'pixelate', 'blackbox'.
        blur_intensity: One of 'low', 'medium', 'high'.

    Returns:
        Processed video file (MP4).
    """
    session = _video_sessions.get(session_id)
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

    ids_to_blur = set(person_ids.split(","))
    video_path = session["video_path"]
    face_id_to_person = session["face_id_to_person"]
    fps = session["fps"]

    # Index detections by frame
    frame_detections: dict[int, list[dict]] = {}
    for det in session["all_detections"]:
        fi = det["frame_index"]
        if fi not in frame_detections:
            frame_detections[fi] = []
        frame_detections[fi].append(det)

    # Process video frame by frame
    output_path = os.path.join(TEMP_DIR, f"{session_id}_output.mp4")
    temp_output = os.path.join(TEMP_DIR, f"{session_id}_temp.avi")

    try:
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            raise HTTPException(
                status_code=500, detail="Could not reopen video."
            )

        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        fourcc = cv2.VideoWriter_fourcc(*"XVID")
        writer = cv2.VideoWriter(temp_output, fourcc, fps, (width, height))

        frame_index = 0
        while True:
            ret, frame = cap.read()
            if not ret:
                break

            # Find nearest detection frame
            nearest_det_frame = (
                frame_index // DETECTION_FRAME_INTERVAL
            ) * DETECTION_FRAME_INTERVAL

            if nearest_det_frame in frame_detections:
                detections = frame_detections[nearest_det_frame]
                frame = blur_processor.blur_video_frame(
                    frame,
                    detections,
                    ids_to_blur,
                    face_id_to_person,
                    style=style,
                    intensity=intensity,
                )

            writer.write(frame)
            frame_index += 1

        cap.release()
        writer.release()

        # Re-encode with ffmpeg to get proper MP4 with audio
        try:
            subprocess.run(
                [
                    "ffmpeg",
                    "-y",
                    "-i", temp_output,
                    "-i", video_path,
                    "-c:v", "libx264",
                    "-preset", "fast",
                    "-crf", "23",
                    "-c:a", "aac",
                    "-map", "0:v:0",
                    "-map", "1:a:0?",
                    "-shortest",
                    output_path,
                ],
                check=True,
                capture_output=True,
                timeout=300,
            )
        except (subprocess.CalledProcessError, FileNotFoundError):
            # If ffmpeg fails or not available, use the AVI directly
            shutil.move(temp_output, output_path)

        # Clean up temp AVI
        if os.path.exists(temp_output):
            os.remove(temp_output)

        # Store output path for cleanup
        session["output_path"] = output_path

        return FileResponse(
            path=output_path,
            media_type="video/mp4",
            filename="blurred_video.mp4",
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Video blur processing failed: {str(e)}",
        )
