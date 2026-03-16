"""Blur processing service supporting Gaussian blur, pixelation, and black box."""

from enum import Enum
from typing import Optional

import cv2
import numpy as np


class BlurStyle(str, Enum):
    GAUSSIAN = "gaussian"
    PIXELATE = "pixelate"
    BLACKBOX = "blackbox"


class BlurIntensity(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


# Gaussian blur kernel sizes and sigma for each intensity
GAUSSIAN_PARAMS = {
    BlurIntensity.LOW: {"ksize": (31, 31), "sigma": 10},
    BlurIntensity.MEDIUM: {"ksize": (61, 61), "sigma": 20},
    BlurIntensity.HIGH: {"ksize": (99, 99), "sigma": 30},
}

# Pixelation block sizes for each intensity
PIXELATE_BLOCK = {
    BlurIntensity.LOW: 10,
    BlurIntensity.MEDIUM: 15,
    BlurIntensity.HIGH: 20,
}


class BlurProcessor:
    """Applies blur effects to face regions in images."""

    def blur_faces(
        self,
        image: np.ndarray,
        bboxes: list[list[int]],
        style: BlurStyle = BlurStyle.GAUSSIAN,
        intensity: BlurIntensity = BlurIntensity.HIGH,
    ) -> np.ndarray:
        """Apply blur to specified face bounding boxes.

        Args:
            image: BGR numpy array.
            bboxes: List of [x, y, w, h] bounding boxes to blur.
            style: Blur style (gaussian, pixelate, blackbox).
            intensity: Blur intensity (low, medium, high).

        Returns:
            Image with blur applied to specified regions.
        """
        result = image.copy()
        h_img, w_img = result.shape[:2]

        for bbox in bboxes:
            x, y, w, h = bbox

            # Clamp to image bounds
            x = max(0, x)
            y = max(0, y)
            w = min(w, w_img - x)
            h = min(h, h_img - y)

            if w <= 0 or h <= 0:
                continue

            roi = result[y : y + h, x : x + w]

            if style == BlurStyle.GAUSSIAN:
                params = GAUSSIAN_PARAMS[intensity]
                blurred_roi = cv2.GaussianBlur(
                    roi, params["ksize"], params["sigma"]
                )
                result[y : y + h, x : x + w] = blurred_roi

            elif style == BlurStyle.PIXELATE:
                block_size = PIXELATE_BLOCK[intensity]
                small = cv2.resize(
                    roi,
                    (max(1, w // block_size), max(1, h // block_size)),
                    interpolation=cv2.INTER_LINEAR,
                )
                pixelated = cv2.resize(
                    small, (w, h), interpolation=cv2.INTER_NEAREST
                )
                result[y : y + h, x : x + w] = pixelated

            elif style == BlurStyle.BLACKBOX:
                result[y : y + h, x : x + w] = 0

        return result

    def blur_video_frame(
        self,
        frame: np.ndarray,
        face_detections: list[dict],
        person_ids_to_blur: set[str],
        face_id_to_person: dict[str, str],
        style: BlurStyle = BlurStyle.GAUSSIAN,
        intensity: BlurIntensity = BlurIntensity.HIGH,
    ) -> np.ndarray:
        """Apply blur to faces belonging to specified persons in a video frame.

        Args:
            frame: BGR numpy array.
            face_detections: List of face dicts with face_id and bbox.
            person_ids_to_blur: Set of person IDs to blur.
            face_id_to_person: Mapping from face_id to person_id.
            style: Blur style.
            intensity: Blur intensity.

        Returns:
            Frame with blur applied.
        """
        bboxes_to_blur = []

        for detection in face_detections:
            face_id = detection["face_id"]
            person_id = face_id_to_person.get(face_id)

            if person_id and person_id in person_ids_to_blur:
                bboxes_to_blur.append(detection["bbox"])

        return self.blur_faces(frame, bboxes_to_blur, style, intensity)


# Singleton instance
blur_processor = BlurProcessor()
