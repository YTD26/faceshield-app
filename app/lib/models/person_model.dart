/// Model representing a unique person detected across video frames.
class PersonModel {
  final String personId;
  final String label;
  final String sampleThumbnailB64;
  final int appearanceCount;
  final List<double> frameTimestamps;
  bool shouldBlur;

  PersonModel({
    required this.personId,
    required this.label,
    required this.sampleThumbnailB64,
    required this.appearanceCount,
    required this.frameTimestamps,
    this.shouldBlur = true,
  });

  factory PersonModel.fromJson(Map<String, dynamic> json) {
    return PersonModel(
      personId: json['person_id'] as String,
      label: json['label'] as String,
      sampleThumbnailB64: json['sample_thumbnail_b64'] as String,
      appearanceCount: json['appearance_count'] as int? ?? 0,
      frameTimestamps: (json['frame_timestamps'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'person_id': personId,
      'label': label,
      'sample_thumbnail_b64': sampleThumbnailB64,
      'appearance_count': appearanceCount,
      'frame_timestamps': frameTimestamps,
      'should_blur': shouldBlur,
    };
  }
}
