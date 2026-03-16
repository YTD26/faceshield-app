"""Face detection service using InsightFace and MediaPipe."""

import base64
import uuid
from io import BytesIO
from typing import Optional

import cv2
import numpy as np
from PIL import Image

try:
    import insightface
    from insightface.app import FaceAnalysis

    INSIGHTFACE_AVAILABLE = True
except ImportError:
    INSIGHTFACE_AVAILABLE = False

try:
    import mediapipe as mp

    MEDIAPIPE_AVAILABLE = True
except ImportError:
    MEDIAPIPE_AVAILABLE = False


class FaceDetector:
    """Detects faces in images and extracts embeddings using InsightFace.
    Falls back to MediaPipe if InsightFace is not available."""

    def __init__(self):
        self._insight_app: Optional[FaceAnalysis] = None
        self._mp_face_detection = None
        self._initialized = False

    def _initialize(self):
        """Lazy initialization of face detection models."""
        if self._initialized:
            return

        if INSIGHTFACE_AVAILABLE:
            try:
                self._insight_app = FaceAnalysis(
                    name="buffalo_l",
                    providers=["CPUExecutionProvider"],
                )
                self._insight_app.prepare(ctx_id=0, det_size=(640, 640))
                self._initialized = True
                print("[FaceDetector] InsightFace initialized successfully.")
                return
            except Exception as e:
                print(f"[FaceDetector] InsightFace init failed: {e}")
                self._insight_app = None

        if MEDIAPIPE_AVAILABLE:
            try:
                self._mp_face_detection = mp.solutions.face_detection.FaceDetection(
                    model_selection=1, min_detection_confidence=0.5
                )
                self._initialized = True
                print("[FaceDetector] MediaPipe initialized as fallback.")
                return
            except Exception as e:
                print(f"[FaceDetector] MediaPipe init failed: {e}")

        raise RuntimeError(
            "No face detection backend available. "
            "Install insightface or mediapipe."
        )

    def detect_faces(self, image: np.ndarray) -> list[dict]:
        """Detect faces in an image.

        Args:
            image: BGR numpy array (OpenCV format).

        Returns:
            List of dicts with keys:
                - face_id: str (UUID)
                - bbox: [x, y, w, h]
                - thumbnail_b64: str (base64-encoded JPEG crop)
                - embedding: list[float] or None (512-dim if InsightFace)
        """
        self._initialize()

        if self._insight_app is not None:
            return self._detect_insightface(image)
        elif self._mp_face_detection is not None:
            return self._detect_mediapipe(image)
        else:
            raise RuntimeError("No face detection backend initialized.")

    def _detect_insightface(self, image: np.ndarray) -> list[dict]:
        """Detect faces using InsightFace."""
        faces = self._insight_app.get(image)
        results = []

        for face in faces:
            bbox = face.bbox.astype(int)
            x1, y1, x2, y2 = bbox
            x = max(0, x1)
            y = max(0, y1)
            w = min(x2, image.shape[1]) - x
            h = min(y2, image.shape[0]) - y

            if w <= 0 or h <= 0:
                continue

            crop = image[y : y + h, x : x + w]
            thumbnail_b64 = self._encode_thumbnail(crop)

            embedding = (
                face.embedding.tolist()
                if face.embedding is not None
                else None
            )

            results.append(
                {
                    "face_id": str(uuid.uuid4()),
                    "bbox": [int(x), int(y), int(w), int(h)],
                    "thumbnail_b64": thumbnail_b64,
                    "embedding": embedding,
                }
            )

        return results

    def _detect_mediapipe(self, image: np.ndarray) -> list[dict]:
        """Detect faces using MediaPipe (no embeddings)."""
        rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        mp_results = self._mp_face_detection.process(rgb)
        results = []

        if not mp_results.detections:
            return results

        h_img, w_img = image.shape[:2]

        for detection in mp_results.detections:
            bb = detection.location_data.relative_bounding_box
            x = max(0, int(bb.xmin * w_img))
            y = max(0, int(bb.ymin * h_img))
            w = min(int(bb.width * w_img), w_img - x)
            h = min(int(bb.height * h_img), h_img - y)

            if w <= 0 or h <= 0:
                continue

            crop = image[y : y + h, x : x + w]
            thumbnail_b64 = self._encode_thumbnail(crop)

            results.append(
                {
                    "face_id": str(uuid.uuid4()),
                    "bbox": [x, y, w, h],
                    "thumbnail_b64": thumbnail_b64,
                    "embedding": None,
                }
            )

        return results

    @staticmethod
    def _encode_thumbnail(crop: np.ndarray, size: int = 112) -> str:
        """Resize face crop and encode as base64 JPEG."""
        if crop.size == 0:
            return ""
        thumbnail = cv2.resize(crop, (size, size), interpolation=cv2.INTER_AREA)
        rgb_thumb = cv2.cvtColor(thumbnail, cv2.COLOR_BGR2RGB)
        pil_img = Image.fromarray(rgb_thumb)
        buffer = BytesIO()
        pil_img.save(buffer, format="JPEG", quality=85)
        return base64.b64encode(buffer.getvalue()).decode("utf-8")


# Singleton instance
face_detector = FaceDetector()
