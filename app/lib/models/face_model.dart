/// Model representing a detected face in a photo.
class FaceModel {
  final String faceId;
  final List<int> bbox; // [x, y, w, h]
  final String thumbnailB64;
  bool shouldBlur;

  FaceModel({
    required this.faceId,
    required this.bbox,
    required this.thumbnailB64,
    this.shouldBlur = true,
  });

  factory FaceModel.fromJson(Map<String, dynamic> json) {
    return FaceModel(
      faceId: json['face_id'] as String,
      bbox: List<int>.from(json['bbox'] as List),
      thumbnailB64: json['thumbnail_b64'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'face_id': faceId,
      'bbox': bbox,
      'thumbnail_b64': thumbnailB64,
      'should_blur': shouldBlur,
    };
  }

  int get x => bbox[0];
  int get y => bbox[1];
  int get width => bbox[2];
  int get height => bbox[3];
}
