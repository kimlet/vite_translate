#include "whisper_bridge.h"
#include "../whisper.cpp/include/whisper.h"
#include <stdlib.h>
#include <string.h>

struct WhisperBridgeContext {
    struct whisper_context* ctx;
};

WhisperBridgeContext* whisper_bridge_init(const char* model_path) {
    struct whisper_context_params cparams = whisper_context_default_params();
    struct whisper_context* ctx = whisper_init_from_file_with_params(model_path, cparams);
    if (!ctx) {
        return NULL;
    }

    WhisperBridgeContext* bridge = (WhisperBridgeContext*)malloc(sizeof(WhisperBridgeContext));
    if (!bridge) {
        whisper_free(ctx);
        return NULL;
    }

    bridge->ctx = ctx;
    return bridge;
}

void whisper_bridge_free(WhisperBridgeContext* ctx) {
    if (ctx) {
        if (ctx->ctx) {
            whisper_free(ctx->ctx);
        }
        free(ctx);
    }
}

WhisperBridgeResult* whisper_bridge_transcribe(
    WhisperBridgeContext* ctx,
    const float* samples,
    int n_samples,
    int detect_language
) {
    if (!ctx || !ctx->ctx || !samples || n_samples <= 0) {
        return NULL;
    }

    struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.print_realtime = 0;
    params.print_progress = 0;
    params.print_timestamps = 0;
    params.print_special = 0;
    params.translate = 0; // We want transcription, not whisper's built-in translate
    params.no_timestamps = 1;
    params.single_segment = 1;

    if (detect_language) {
        params.language = NULL; // Auto-detect
        params.detect_language = 1;
    } else {
        params.language = "auto";
    }

    int ret = whisper_full(ctx->ctx, params, samples, n_samples);
    if (ret != 0) {
        return NULL;
    }

    WhisperBridgeResult* result = (WhisperBridgeResult*)malloc(sizeof(WhisperBridgeResult));
    if (!result) {
        return NULL;
    }

    // Get transcription text
    int n_segments = whisper_full_n_segments(ctx->ctx);
    if (n_segments > 0) {
        const char* text = whisper_full_get_segment_text(ctx->ctx, 0);
        result->text = strdup(text ? text : "");
    } else {
        result->text = strdup("");
    }

    // Get detected language
    int lang_id = whisper_full_lang_id(ctx->ctx);
    if (lang_id >= 0) {
        const char* lang = whisper_lang_str(lang_id);
        result->language = strdup(lang ? lang : "en");
    } else {
        result->language = strdup("en");
    }

    // Get language probability
    result->language_probability = whisper_full_lang_id(ctx->ctx) >= 0 ? 1.0f : 0.0f;

    return result;
}

void whisper_bridge_free_result(WhisperBridgeResult* result) {
    if (result) {
        free((void*)result->text);
        free((void*)result->language);
        free(result);
    }
}
