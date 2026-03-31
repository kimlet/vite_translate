#include "whisper_bridge.h"
#include "../whisper.cpp/include/whisper.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#ifdef __ANDROID__
#include <android/log.h>
#define LOG_TAG "WhisperBridge"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#else
#define LOGD(...) fprintf(stderr, __VA_ARGS__)
#endif

struct WhisperBridgeContext {
    struct whisper_context* ctx;
};

WhisperBridgeContext* whisper_bridge_init(const char* model_path) {
    LOGD("whisper_bridge_init: loading model from %s\n", model_path);

    struct whisper_context_params cparams = whisper_context_default_params();
    struct whisper_context* ctx = whisper_init_from_file_with_params(model_path, cparams);
    if (!ctx) {
        LOGD("whisper_bridge_init: FAILED to load model\n");
        return NULL;
    }

    WhisperBridgeContext* bridge = (WhisperBridgeContext*)malloc(sizeof(WhisperBridgeContext));
    if (!bridge) {
        whisper_free(ctx);
        return NULL;
    }

    bridge->ctx = ctx;
    LOGD("whisper_bridge_init: model loaded successfully\n");
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
        LOGD("whisper_bridge_transcribe: invalid args (ctx=%p, samples=%p, n=%d)\n",
             (void*)ctx, (void*)samples, n_samples);
        return NULL;
    }

    LOGD("whisper_bridge_transcribe: %d samples (%.1f sec)\n",
         n_samples, (float)n_samples / 16000.0f);

    struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.print_realtime = 0;
    params.print_progress = 0;
    params.print_timestamps = 0;
    params.print_special = 0;
    params.translate = 0;
    params.no_timestamps = 1;
    params.single_segment = 0; // Allow multiple segments
    params.n_threads = 4;

    // Always set language to "auto" for auto-detection + transcription.
    // Setting language=NULL with detect_language=1 only detects without transcribing.
    params.language = "auto";
    params.detect_language = 0;

    int ret = whisper_full(ctx->ctx, params, samples, n_samples);
    LOGD("whisper_bridge_transcribe: whisper_full returned %d\n", ret);

    if (ret != 0) {
        LOGD("whisper_bridge_transcribe: whisper_full FAILED\n");
        return NULL;
    }

    WhisperBridgeResult* result = (WhisperBridgeResult*)malloc(sizeof(WhisperBridgeResult));
    if (!result) {
        return NULL;
    }

    // Collect text from all segments
    int n_segments = whisper_full_n_segments(ctx->ctx);
    LOGD("whisper_bridge_transcribe: %d segments\n", n_segments);

    if (n_segments > 0) {
        // Calculate total text length
        int total_len = 0;
        for (int i = 0; i < n_segments; i++) {
            const char* seg_text = whisper_full_get_segment_text(ctx->ctx, i);
            if (seg_text) {
                total_len += strlen(seg_text);
            }
        }

        // Concatenate all segments
        char* full_text = (char*)malloc(total_len + 1);
        full_text[0] = '\0';
        for (int i = 0; i < n_segments; i++) {
            const char* seg_text = whisper_full_get_segment_text(ctx->ctx, i);
            if (seg_text) {
                strcat(full_text, seg_text);
            }
        }
        result->text = full_text;
        LOGD("whisper_bridge_transcribe: text=\"%s\"\n", full_text);
    } else {
        result->text = strdup("");
        LOGD("whisper_bridge_transcribe: no segments, empty text\n");
    }

    // Get detected language
    int lang_id = whisper_full_lang_id(ctx->ctx);
    if (lang_id >= 0) {
        const char* lang = whisper_lang_str(lang_id);
        result->language = strdup(lang ? lang : "en");
        LOGD("whisper_bridge_transcribe: detected language=%s (id=%d)\n",
             result->language, lang_id);
    } else {
        result->language = strdup("en");
        LOGD("whisper_bridge_transcribe: no language detected, defaulting to en\n");
    }

    result->language_probability = lang_id >= 0 ? 1.0f : 0.0f;

    return result;
}

void whisper_bridge_free_result(WhisperBridgeResult* result) {
    if (result) {
        free((void*)result->text);
        free((void*)result->language);
        free(result);
    }
}
