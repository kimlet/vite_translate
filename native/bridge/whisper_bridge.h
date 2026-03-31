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

/// Transcribe audio samples.
/// @param ctx The whisper context.
/// @param samples PCM float32 samples, 16kHz mono.
/// @param n_samples Number of samples.
/// @param detect_language 1 to auto-detect language, 0 to skip.
/// @return Transcription result. The caller must call whisper_bridge_free_result() after use.
WhisperBridgeResult* whisper_bridge_transcribe(
    WhisperBridgeContext* ctx,
    const float* samples,
    int n_samples,
    int detect_language
);

/// Free a transcription result.
void whisper_bridge_free_result(WhisperBridgeResult* result);

#ifdef __cplusplus
}
#endif

#endif // WHISPER_BRIDGE_H
