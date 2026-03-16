"""API routers for photo and video processing."""

from .photo import router as photo_detect_router
from .photo import blur_router as photo_blur_router
from .video import router as video_detect_router
from .video import blur_router as video_blur_router

__all__ = [
    "photo_detect_router",
    "photo_blur_router",
    "video_detect_router",
    "video_blur_router",
]
