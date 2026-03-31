const String kAppName = 'vibeTranslate';

const int kSampleRate = 16000;
const int kChannels = 1;
const int kBitsPerSample = 16;

const int kVadFrameDurationMs = 30;
const int kVadSilenceThresholdMs = 300;
const double kVadEnergyThreshold = 0.01;

const int kPartialTranscriptionIntervalMs = 1000;

const int kWhisperMaxAudioLengthSec = 30;

const String kWhisperModelFileName = 'ggml-base.bin';
const String kNllbModelDirName = 'nllb-200-distilled-600M-ct2-int8';

const String kModelsBaseUrl =
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';
const String kWhisperModelUrl = '$kModelsBaseUrl/$kWhisperModelFileName';
