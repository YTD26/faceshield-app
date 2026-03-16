"""Face clustering service using cosine similarity on InsightFace embeddings."""

import uuid
from typing import Optional

import numpy as np


class FaceClusterer:
    """Clusters detected faces across video frames into unique persons
    using cosine similarity on 512-dim face embeddings."""

    SIMILARITY_THRESHOLD = 0.4

    def cluster_faces(
        self, all_detections: list[dict]
    ) -> list[dict]:
        """Cluster face detections into unique persons.

        Args:
            all_detections: List of detection dicts, each with keys:
                - face_id: str
                - bbox: [x, y, w, h]
                - thumbnail_b64: str
                - embedding: list[float] or None
                - frame_index: int
                - timestamp: float

        Returns:
            List of person dicts:
                - person_id: str
                - label: str (e.g. "Person 1")
                - sample_thumbnail_b64: str
                - face_ids: list[str]
                - frame_timestamps: list[float]
        """
        if not all_detections:
            return []

        # Separate faces with and without embeddings
        faces_with_emb = [
            d for d in all_detections if d.get("embedding") is not None
        ]
        faces_without_emb = [
            d for d in all_detections if d.get("embedding") is None
        ]

        persons: list[dict] = []

        if faces_with_emb:
            persons = self._cluster_with_embeddings(faces_with_emb)

        # Faces without embeddings get assigned as individual persons
        for face in faces_without_emb:
            person_idx = len(persons) + 1
            persons.append(
                {
                    "person_id": str(uuid.uuid4()),
                    "label": f"Person {person_idx}",
                    "sample_thumbnail_b64": face["thumbnail_b64"],
                    "face_ids": [face["face_id"]],
                    "frame_timestamps": [face.get("timestamp", 0.0)],
                }
            )

        return persons

    def _cluster_with_embeddings(
        self, detections: list[dict]
    ) -> list[dict]:
        """Cluster faces using cosine similarity on embeddings."""
        clusters: list[dict] = []
        # Each cluster stores: centroid (mean embedding), face_ids, timestamps, thumbnail

        for detection in detections:
            emb = np.array(detection["embedding"], dtype=np.float32)
            emb_norm = emb / (np.linalg.norm(emb) + 1e-10)

            best_cluster_idx: Optional[int] = None
            best_similarity = -1.0

            for idx, cluster in enumerate(clusters):
                centroid = cluster["centroid"]
                similarity = float(np.dot(emb_norm, centroid))

                if (
                    similarity > self.SIMILARITY_THRESHOLD
                    and similarity > best_similarity
                ):
                    best_similarity = similarity
                    best_cluster_idx = idx

            if best_cluster_idx is not None:
                # Add to existing cluster
                cluster = clusters[best_cluster_idx]
                cluster["face_ids"].append(detection["face_id"])
                cluster["frame_timestamps"].append(
                    detection.get("timestamp", 0.0)
                )
                # Update centroid as running mean
                n = len(cluster["face_ids"])
                cluster["centroid"] = (
                    cluster["centroid"] * (n - 1) + emb_norm
                ) / n
                cluster["centroid"] /= (
                    np.linalg.norm(cluster["centroid"]) + 1e-10
                )
            else:
                # Create new cluster
                clusters.append(
                    {
                        "person_id": str(uuid.uuid4()),
                        "centroid": emb_norm,
                        "sample_thumbnail_b64": detection["thumbnail_b64"],
                        "face_ids": [detection["face_id"]],
                        "frame_timestamps": [
                            detection.get("timestamp", 0.0)
                        ],
                    }
                )

        # Format output
        persons = []
        for idx, cluster in enumerate(clusters):
            persons.append(
                {
                    "person_id": cluster["person_id"],
                    "label": f"Person {idx + 1}",
                    "sample_thumbnail_b64": cluster["sample_thumbnail_b64"],
                    "face_ids": cluster["face_ids"],
                    "frame_timestamps": cluster["frame_timestamps"],
                }
            )

        return persons


# Singleton instance
face_clusterer = FaceClusterer()
