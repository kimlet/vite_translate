# vibeTranslate

Real-time offline auto-translation conversation app built with Flutter.

Set your primary language, start talking, and vibeTranslate automatically detects what language is being spoken, transcribes it, and translates it — all on-device, no internet required, no buttons to press.

## How It Works

```
Microphone -> VAD -> whisper.cpp (ASR + language detect + translate) -> Conversation UI
```

1. **Always-on listening** — microphone streams audio continuously
2. **Voice Activity Detection (VAD)** — energy-based detection segments speech from silence
3. **whisper.cpp** — on-device speech recognition with automatic language detection
4. **Built-in translation** — whisper translates foreign speech to English (when primary language is English)
5. **Audio saved** — every utterance is saved as WAV for replay

### Translation Strategy

- Someone speaks a foreign language -> transcribed in original language + translated to English
- You speak your primary language -> transcribed as-is
- Each message bubble shows original text (small) and translation (large)
- Tap the play button on any message to replay the audio

## Tech Stack

| Component | Technology |
|-----------|-----------|
| UI Framework | Flutter (iOS + Android) |
| Speech Recognition | [whisper.cpp](https://github.com/ggerganov/whisper.cpp) via Dart FFI |
| Translation | Whisper built-in (speech -> English) |
| Model | ggml-tiny (75MB) or ggml-base (142MB) |
| State Management | Riverpod |
| Audio Capture | `record` package (PCM 16kHz mono) |
| Audio Playback | `audioplayers` package |
| Native Integration | Dart FFI with C bridge layer |
| Future Translation | NLLB-200 via ONNX Runtime (for non-English primary languages) |

## Project Structure

```
vibe_translate/
├── lib/
│   ├── main.dart                          # Entry point
│   ├── app.dart                           # MaterialApp with Riverpod, routing
│   │
│   ├── core/
│   │   ├── constants.dart                 # Sample rate, VAD thresholds, model config
│   │   ├── errors.dart                    # Custom exception types
│   │   └── language_codes.dart            # Whisper ISO 639-1 <-> NLLB code mapping (90+ languages)
│   │
│   ├── models/
│   │   ├── conversation_message.dart      # Message with original + translated text + audio path
│   │   ├── language.dart                  # Language code/name/NLLB code
│   │   └── transcription_result.dart      # ASR output with detected language
│   │
│   ├── services/
│   │   ├── asr/
│   │   │   ├── whisper_bindings.dart      # Dart FFI bindings for whisper C bridge
│   │   │   ├── whisper_service.dart       # High-level transcribe + translate API
│   │   │   └── whisper_isolate.dart       # Runs whisper in separate Dart isolate
│   │   │
│   │   ├── audio/
│   │   │   ├── audio_recorder.dart        # PCM 16kHz mono capture via record package
│   │   │   ├── audio_stream_controller.dart # VAD + utterance segmentation
│   │   │   ├── audio_saver.dart           # Saves Float32 PCM to WAV files
│   │   │   ├── audio_player_service.dart  # Replay saved audio via audioplayers
│   │   │   ├── vad_service.dart           # Energy-based voice activity detection
│   │   │   └── test_audio_service.dart    # Load WAV from assets for testing
│   │   │
│   │   ├── translation/
│   │   │   ├── translation_service.dart   # ONNX Runtime + SentencePiece for NLLB (future)
│   │   │   └── translation_isolate.dart   # Async wrapper for translation
│   │   │
│   │   ├── conversation_engine.dart       # Orchestrator: audio -> ASR -> translate -> messages
│   │   └── model_manager.dart             # Download, verify, locate ML models
│   │
│   ├── state/                             # Riverpod providers
│   │   ├── conversation_state.dart        # Messages list, partial transcription, demo mode
│   │   ├── settings_state.dart            # Primary language, onboarding status
│   │   └── engine_state.dart              # Model load status, download progress
│   │
│   └── ui/
│       ├── screens/
│       │   ├── conversation_screen.dart   # Main screen: chat bubbles + test buttons
│       │   ├── settings_screen.dart       # Primary language picker
│       │   └── onboarding_screen.dart     # First-run: language + permissions + model download
│       │
│       ├── widgets/
│       │   ├── message_bubble.dart        # Original text + translation + play button
│       │   ├── partial_transcription.dart # Live "listening..." indicator
│       │   ├── recording_indicator.dart   # Pulsing recording status
│       │   ├── language_badge.dart        # Language tag pill
│       │   └── language_picker.dart       # Searchable language list
│       │
│       └── theme.dart                     # Material 3 theme (indigo/violet)
│
├── native/
│   ├── whisper.cpp/                       # Git submodule
│   ├── bridge/
│   │   ├── whisper_bridge.h / .c          # C bridge: init, transcribe, translate, free
│   │   ├── ct2_bridge.h / .cpp            # CTranslate2 bridge (placeholder)
│   │   └── sentencepiece_bridge.h / .cpp  # SentencePiece tokenizer bridge (placeholder)
│   ├── android/CMakeLists.txt             # Android NDK build (whisper + bridges)
│   ├── vibe_translate_native.podspec      # iOS CocoaPods build (whisper + bridges)
│   └── CMakeLists.txt                     # Top-level CMake reference
│
├── assets/
│   ├── models/                            # ML models (not in git, download separately)
│   └── test_audio/
│       └── test_english.wav               # Sample English audio for testing
│
├── scripts/
│   ├── download_models.sh                 # Download whisper model from HuggingFace
│   ├── build_ios_whisper.sh               # Pre-build whisper as xcframework (optional)
│   ├── convert_nllb.py                    # Convert NLLB to CTranslate2 format
│   └── export_nllb_onnx.py               # Export NLLB to ONNX format
│
├── ios/                                   # iOS project (CocoaPods, permissions)
├── android/                               # Android project (CMake, permissions)
└── test/
    └── widget_test.dart
```

## Getting Started

### Prerequisites

- Flutter 3.38+ (via [FVM](https://fvm.app/) recommended)
- Xcode 16+ (iOS) with Metal Toolchain
- Android Studio / NDK (Android)

### Setup

```bash
# Clone with submodules
git clone --recursive <repo-url>
cd vibe_translate

# Get Flutter dependencies
fvm flutter pub get

# Download whisper model (~75MB for tiny, ~142MB for base)
./scripts/download_models.sh
```

### Run on Android

```bash
fvm flutter build apk
fvm flutter install

# Push the model to the device
adb push assets/models/ggml-tiny.bin /sdcard/Download/
adb shell "run-as com.vibetranslate.vibe_translate mkdir -p files/models && cp /sdcard/Download/ggml-tiny.bin files/models/"
```

### Run on iOS

```bash
cd ios && pod install && cd ..
fvm flutter build ios
```

> Note: Requires Metal Toolchain installed in Xcode (Settings > Components). Without it, disable Metal in the podspec and use CPU-only inference.

## App Buttons

| Button | Icon | Action |
|--------|------|--------|
| Test Audio | Mic icon | Feed bundled WAV file through whisper pipeline |
| Run Demo | Play icon | Simulate multilingual conversation with fake data |
| Clear | Trash icon | Clear all messages |
| Settings | Gear icon | Change primary language |

## Architecture

### Audio Pipeline

```
Mic (16kHz PCM) -> AudioStreamController -> VAD -> Utterance (Float32List)
                                                      |
                                              AudioSaver (WAV file)
                                                      |
                                              WhisperIsolate (separate thread)
                                                      |
                                         Transcribe (original text + language)
                                                      |
                                    [if foreign language & primary=en]
                                                      |
                                         Translate to English (whisper built-in)
                                                      |
                                              ConversationMessage
                                                      |
                                              UI (message bubble + play button)
```

### Key Design Decisions

- **Dart Isolate for whisper**: Inference runs off the main thread to keep UI responsive
- **Energy-based VAD**: Simple RMS threshold (~20 lines of Dart), no extra model needed
- **Whisper built-in translation**: Avoids needing a separate NLLB model for English-primary users
- **Audio saved per utterance**: WAV files in app documents directory for replay
- **Graceful degradation**: App works without translation model (transcription-only mode)

## Models

| Model | Size | Speed | Quality |
|-------|------|-------|---------|
| ggml-tiny | 75MB | Fast (~0.5s/utterance) | Good for common languages |
| ggml-base | 142MB | Medium (~1-2s/utterance) | Better accuracy |
| ggml-small | 466MB | Slow (~3-5s/utterance) | Best accuracy |

Download from: https://huggingface.co/ggerganov/whisper.cpp

## Roadmap

- [ ] NLLB translation for non-English primary languages (ONNX Runtime integration ready)
- [ ] Speaker diarization (who is speaking)
- [ ] Conversation export (text + audio)
- [ ] Quantized whisper models for faster inference
- [ ] iOS Metal GPU acceleration for whisper
- [ ] Background audio mode
