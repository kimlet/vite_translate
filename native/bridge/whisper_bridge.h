#ifndef WHISPER_BRIDGE_H
#define WHISPER_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct WhisperBridgeContext WhisperBridgeContext;

/// Result from transcription.
typedef struct {
    const char* text;
    const char* language;
    float language_probability;
} WhisperBridgeResult;

/// Initialize whisper context from a model file path.
/// Returns NULL on failure.
WhisperBridgeContext* whisper_bridge_init(const char* model_path);

/// Free the whisper context and all associated resources.
void whisper_bridge_free(WhisperBridgeContext* ctx);

/// Transcribe audio samples (keep original language).
/// @param ctx The whisper context.
/// @param samples PCM float32 samples, 16kHz mono.
/// @param n_samples Number of samples.
/// @return Transcription result. Caller must call whisper_bridge_free_result().
WhisperBridgeResult* whisper_bridge_transcribe(
    WhisperBridgeContext* ctx,
    const float* samples,
    int n_samples,
    int detect_language
);

/// Translate audio to English text (whisper's built-in translation).
/// @param ctx The whisper context.
/// @param samples PCM float32 samples, 16kHz mono.
/// @param n_samples Number of samples.
/// @return Translation result. Caller must call whisper_bridge_free_result().
WhisperBridgeResult* whisper_bridge_translate(
    WhisperBridgeContext* ctx,
    const float* samples,
    int n_samples
);

/// Free a transcription result.
void whisper_bridge_free_result(WhisperBridgeResult* result);

#ifdef __cplusplus
}
#endif

#endif // WHISPER_BRIDGE_H
