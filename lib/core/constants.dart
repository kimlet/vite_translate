const String kAppName = 'vibeTranslate';

const int kSampleRate = 16000;
const int kChannels = 1;
const int kBitsPerSample = 16;

const int kVadFrameDurationMs = 30;
const int kVadSilenceThresholdMs = 500; // slightly longer to avoid cutting mid-sentence
const double kVadEnergyThreshold = 0.008; // slightly more sensitive
const int kVadMinSpeechMs = 300; // minimum speech duration to process

const int kPartialTranscriptionIntervalMs = 1500;

const int kWhisperMaxAudioLengthSec = 30;

// Use tiny model for real-time performance on mobile
const String kWhisperModelFileName = 'ggml-tiny.bin';
const String kNllbModelDirName = 'nllb-200-distilled-600M-ct2-int8';

const String kModelsBaseUrl =
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';
const String kWhisperModelUrl = '$kModelsBaseUrl/$kWhisperModelFileName';
