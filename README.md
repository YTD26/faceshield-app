# FaceShield

**AI-powered face detection and blurring for photos and videos.**

FaceShield is a cross-platform mobile app (iOS & Android) built with Flutter and a Python FastAPI backend. It uses AI to detect faces in photos and videos, allowing users to selectively blur faces to protect privacy before sharing content online.

![FaceShield](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.22-02569B?logo=flutter)
![FastAPI](https://img.shields.io/badge/FastAPI-0.109-009688?logo=fastapi)
![License](https://img.shields.io/badge/License-MIT-green)

---

## Screenshots

| Home | Photo Mode | Video Mode | Settings |
|------|-----------|-----------|----------|
| *Coming soon* | *Coming soon* | *Coming soon* | *Coming soon* |

---

## Features

### Photo Mode
- Pick photos from camera or gallery
- AI-powered face detection with bounding box overlays
- Toggle blur on/off per face with thumbnail grid
- Apply Gaussian blur, pixelation, or black box
- Save to gallery or share directly

### Video Mode
- Select videos up to 5 minutes long
- AI detects and clusters faces across frames into unique persons
- Select which persons to blur
- Process and preview blurred video
- Save or share the result

### Privacy & GDPR
- All uploaded files auto-deleted from server within 60 seconds
- No face data or biometric information stored server-side
- Consent dialog on first launch
- Local history stored only on device using `shared_preferences`

### Settings
- Blur style: Gaussian Blur / Pixelate / Black Box
- Blur intensity: Low / Medium / High
- Auto-delete from server toggle
- Server connection test
- GDPR compliance information

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Mobile App | Flutter 3.22 (Dart) |
| Backend API | Python FastAPI |
| Face Detection | InsightFace / MediaPipe |
| Face Clustering | Cosine similarity on 512-dim embeddings |
| Video Processing | OpenCV + FFmpeg |
| Containerization | Docker |
| CI/CD | GitHub Actions |

---

## Project Structure

```
faceshield-app/
├── app/                        # Flutter mobile app
│   ├── lib/
│   │   ├── main.dart           # App entry point + navigation
│   │   ├── screens/
│   │   │   ├── home_screen.dart
│   │   │   ├── photo_mode_screen.dart
│   │   │   ├── video_mode_screen.dart
│   │   │   ├── history_screen.dart
│   │   │   └── settings_screen.dart
│   │   ├── widgets/
│   │   │   ├── face_thumbnail_grid.dart
│   │   │   ├── blur_overlay_painter.dart
│   │   │   └── video_player_widget.dart
│   │   ├── services/
│   │   │   ├── api_service.dart
│   │   │   └── storage_service.dart
│   │   └── models/
│   │       ├── face_model.dart
│   │       └── person_model.dart
│   ├── pubspec.yaml
│   ├── android/
│   └── ios/
├── backend/                    # Python FastAPI backend
│   ├── main.py                 # FastAPI app + CORS + auto-cleanup
│   ├── routers/
│   │   ├── photo.py            # Photo detect + blur endpoints
│   │   └── video.py            # Video detect + blur endpoints
│   ├── services/
│   │   ├── face_detector.py    # InsightFace/MediaPipe detection
│   │   ├── face_clusterer.py   # Cosine similarity clustering
│   │   └── blur_processor.py   # Gaussian/pixelate/blackbox blur
│   ├── requirements.txt
│   └── Dockerfile
├── .github/
│   └── workflows/
│       └── flutter_build.yml   # CI: test + build APK + IPA
├── docker-compose.yml
└── README.md
```

---

## Setup & Installation

### Prerequisites
- Flutter SDK 3.22+ ([install](https://docs.flutter.dev/get-started/install))
- Python 3.11+ ([install](https://www.python.org/downloads/))
- Docker & Docker Compose (optional, for backend)
- FFmpeg (for video processing)

### Backend Setup

#### Option 1: Docker (Recommended)

```bash
# Clone the repository
git clone https://github.com/YTD26/faceshield-app.git
cd faceshield-app

# Start the backend
docker-compose up -d

# Backend will be available at http://localhost:8000
```

#### Option 2: Manual Setup

```bash
cd backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate   # Windows

# Install dependencies
pip install -r requirements.txt

# Run the server
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Flutter App Setup

```bash
cd app

# Install dependencies
flutter pub get

# Run on Android emulator or connected device
flutter run

# Build release APK
flutter build apk --release

# Build iOS (requires macOS with Xcode)
flutter build ipa --no-codesign
```

### Configuration

Update the backend URL in `app/lib/services/api_service.dart`:

```dart
// For Android Emulator (default)
static String baseUrl = 'http://10.0.2.2:8000';

// For iOS Simulator
static String baseUrl = 'http://localhost:8000';

// For physical device (use your machine's IP)
static String baseUrl = 'http://192.168.1.100:8000';

// For production
static String baseUrl = 'https://api.yourserver.com';
```

---

## API Documentation

The backend exposes a RESTful API. Interactive documentation is available at `http://localhost:8000/docs` when the server is running.

### Endpoints

#### `GET /health`
Health check endpoint.

**Response:** `{"status": "healthy"}`

---

#### `POST /detect/photo`
Detect faces in an uploaded photo.

**Request:** `multipart/form-data` with `file` (image)

**Response:**
```json
{
  "session_id": "uuid",
  "faces": [
    {
      "face_id": "uuid",
      "bbox": [x, y, width, height],
      "thumbnail_b64": "base64-encoded-jpeg"
    }
  ],
  "face_count": 3,
  "image_width": 1920,
  "image_height": 1080
}
```

---

#### `POST /blur/photo`
Apply blur to specified faces.

**Request:** `multipart/form-data`
| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | From `/detect/photo` response |
| `face_ids` | string | Comma-separated face IDs to blur |
| `blur_style` | string | `gaussian`, `pixelate`, or `blackbox` |
| `blur_intensity` | string | `low`, `medium`, or `high` |

**Response:** JPEG image binary

---

#### `POST /detect/video`
Detect and cluster faces across video frames.

**Request:** `multipart/form-data` with `file` (video, max 5 min)

**Response:**
```json
{
  "session_id": "uuid",
  "persons": [
    {
      "person_id": "uuid",
      "label": "Person 1",
      "sample_thumbnail_b64": "base64-jpeg",
      "appearance_count": 47,
      "frame_timestamps": [0.0, 0.5, 1.0]
    }
  ],
  "person_count": 3,
  "video_duration": 120.5
}
```

---

#### `POST /blur/video`
Apply blur to specified persons across all video frames.

**Request:** `multipart/form-data`
| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | From `/detect/video` response |
| `person_ids` | string | Comma-separated person IDs to blur |
| `blur_style` | string | `gaussian`, `pixelate`, or `blackbox` |
| `blur_intensity` | string | `low`, `medium`, or `high` |

**Response:** MP4 video binary

---

#### `DELETE /cleanup/{session_id}`
Manually delete all temporary server data for a session.

**Response:** `{"status": "cleaned", "session_id": "uuid"}`

---

## Face Detection & Clustering

### Detection
FaceShield uses **InsightFace** (buffalo_l model) as the primary face detector, with **MediaPipe** as a fallback. InsightFace provides:
- High-accuracy face detection
- 512-dimensional face embeddings for clustering
- Robust performance across angles and lighting

### Clustering (Video Mode)
Faces detected across video frames are clustered into unique persons using:
1. Extract 512-dim embeddings per face (InsightFace)
2. Compute cosine similarity between embeddings
3. Group faces with similarity > 0.4 threshold
4. Assign stable person IDs with running mean centroids

### Blur Processing
Three blur styles are supported:

| Style | Method |
|-------|--------|
| Gaussian | `cv2.GaussianBlur(roi, (ksize, ksize), sigma)` |
| Pixelate | Downscale + nearest-neighbor upscale |
| Black Box | Fill ROI with black (0, 0, 0) |

---

## GitHub Actions CI/CD

The workflow (`.github/workflows/flutter_build.yml`) runs on every push to `main`:

1. **Test** — `flutter analyze` + `flutter test`
2. **Build Android** — Produces release APK artifact
3. **Build iOS** — Produces unsigned IPA artifact (requires macOS runner)

Build artifacts are available for download from the Actions tab.

---

## Docker Deployment

### Production Deployment

```bash
# Build and start
docker-compose up -d --build

# Check logs
docker-compose logs -f backend

# Stop
docker-compose down
```

The backend container:
- Runs on port 8000
- Includes FFmpeg for video processing
- Auto-restarts on failure
- Limited to 4GB RAM / 2 CPUs
- Health check every 30 seconds

---

## Design

- **Material 3** with dark mode
- Primary: Deep Blue `#1A237E`
- Accent: Cyan `#00BCD4`
- Smooth animations for blur toggles (AnimatedContainer)
- Shimmer loading effects during processing
- English UI with Dutch locale support (`nl_NL`)

---

## License

This project is licensed under the MIT License.

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request
