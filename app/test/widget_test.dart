import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:faceshield/main.dart';
import 'package:faceshield/models/face_model.dart';
import 'package:faceshield/models/person_model.dart';

void main() {
  group('FaceModel', () {
    test('creates from JSON correctly', () {
      final json = {
        'face_id': 'test-id-123',
        'bbox': [10, 20, 100, 150],
        'thumbnail_b64': 'base64data',
      };

      final face = FaceModel.fromJson(json);

      expect(face.faceId, 'test-id-123');
      expect(face.bbox, [10, 20, 100, 150]);
      expect(face.x, 10);
      expect(face.y, 20);
      expect(face.width, 100);
      expect(face.height, 150);
      expect(face.thumbnailB64, 'base64data');
      expect(face.shouldBlur, true); // default
    });

    test('serializes to JSON correctly', () {
      final face = FaceModel(
        faceId: 'abc',
        bbox: [5, 10, 50, 60],
        thumbnailB64: 'thumb',
        shouldBlur: false,
      );

      final json = face.toJson();
      expect(json['face_id'], 'abc');
      expect(json['bbox'], [5, 10, 50, 60]);
      expect(json['should_blur'], false);
    });

    test('shouldBlur toggles correctly', () {
      final face = FaceModel(
        faceId: 'toggle-test',
        bbox: [0, 0, 10, 10],
        thumbnailB64: '',
      );

      expect(face.shouldBlur, true);
      face.shouldBlur = false;
      expect(face.shouldBlur, false);
    });
  });

  group('PersonModel', () {
    test('creates from JSON correctly', () {
      final json = {
        'person_id': 'person-1',
        'label': 'Person 1',
        'sample_thumbnail_b64': 'thumbdata',
        'appearance_count': 15,
        'frame_timestamps': [0.0, 0.5, 1.0, 1.5],
      };

      final person = PersonModel.fromJson(json);

      expect(person.personId, 'person-1');
      expect(person.label, 'Person 1');
      expect(person.sampleThumbnailB64, 'thumbdata');
      expect(person.appearanceCount, 15);
      expect(person.frameTimestamps.length, 4);
      expect(person.shouldBlur, true); // default
    });

    test('handles missing optional fields', () {
      final json = {
        'person_id': 'person-2',
        'label': 'Person 2',
        'sample_thumbnail_b64': '',
      };

      final person = PersonModel.fromJson(json);
      expect(person.appearanceCount, 0);
      expect(person.frameTimestamps, isEmpty);
    });

    test('serializes to JSON correctly', () {
      final person = PersonModel(
        personId: 'p1',
        label: 'Person 1',
        sampleThumbnailB64: 'data',
        appearanceCount: 5,
        frameTimestamps: [1.0, 2.0],
        shouldBlur: false,
      );

      final json = person.toJson();
      expect(json['person_id'], 'p1');
      expect(json['label'], 'Person 1');
      expect(json['should_blur'], false);
      expect(json['appearance_count'], 5);
    });
  });

  group('FaceShieldApp', () {
    testWidgets('renders app title', (WidgetTester tester) async {
      await tester.pumpWidget(const FaceShieldApp());
      await tester.pumpAndSettle();

      expect(find.text('FaceShield'), findsOneWidget);
    });

    testWidgets('shows Photo and Video buttons on home', (WidgetTester tester) async {
      await tester.pumpWidget(const FaceShieldApp());
      await tester.pumpAndSettle();

      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);
    });

    testWidgets('has bottom navigation bar', (WidgetTester tester) async {
      await tester.pumpWidget(const FaceShieldApp());
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
