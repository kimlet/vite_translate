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
    LOGD("whisper_bridge_init: model loaded OK\n");
    return bridge;
}

void whisper_bridge_free(WhisperBridgeContext* ctx) {
    if (ctx) {
        if (ctx->ctx) whisper_free(ctx->ctx);
        free(ctx);
    }
}

static WhisperBridgeResult* run_whisper(
    WhisperBridgeContext* ctx,
    const float* samples,
    int n_samples,
    int do_translate
) {
    if (!ctx || !ctx->ctx || !samples || n_samples <= 0) {
        LOGD("run_whisper: invalid args\n");
        return NULL;
    }

    LOGD("run_whisper: %d samples (%.1fs), translate=%d\n",
         n_samples, (float)n_samples / 16000.0f, do_translate);

    struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.print_realtime   = 0;
    params.print_progress   = 0;
    params.print_timestamps = 0;
    params.print_special    = 0;
    params.no_timestamps    = 1;
    params.single_segment   = 0;
    params.n_threads        = 4;
    params.language         = "auto";
    params.detect_language  = 0;
    params.translate        = do_translate; // 0=transcribe, 1=translate to English

    int ret = whisper_full(ctx->ctx, params, samples, n_samples);
    LOGD("run_whisper: whisper_full returned %d\n", ret);
    if (ret != 0) return NULL;

    int n_segments = whisper_full_n_segments(ctx->ctx);
    LOGD("run_whisper: %d segments\n", n_segments);

    WhisperBridgeResult* result = (WhisperBridgeResult*)malloc(sizeof(WhisperBridgeResult));
    if (!result) return NULL;

    // Collect all segment text
    if (n_segments > 0) {
        int total_len = 0;
        for (int i = 0; i < n_segments; i++) {
            const char* t = whisper_full_get_segment_text(ctx->ctx, i);
            if (t) total_len += strlen(t);
        }
        char* full_text = (char*)malloc(total_len + 1);
        full_text[0] = '\0';
        for (int i = 0; i < n_segments; i++) {
            const char* t = whisper_full_get_segment_text(ctx->ctx, i);
            if (t) strcat(full_text, t);
        }
        result->text = full_text;
    } else {
        result->text = strdup("");
    }

    // Detected language
    int lang_id = whisper_full_lang_id(ctx->ctx);
    if (lang_id >= 0) {
        result->language = strdup(whisper_lang_str(lang_id));
    } else {
        result->language = strdup("en");
    }
    result->language_probability = lang_id >= 0 ? 1.0f : 0.0f;

    LOGD("run_whisper: lang=%s text=\"%.80s%s\"\n",
         result->language, result->text,
         strlen(result->text) > 80 ? "..." : "");

    return result;
}

WhisperBridgeResult* whisper_bridge_transcribe(
    WhisperBridgeContext* ctx,
    const float* samples,
    int n_samples,
    int detect_language
) {
    (void)detect_language; // always auto-detect via language="auto"
    return run_whisper(ctx, samples, n_samples, 0);
}

WhisperBridgeResult* whisper_bridge_translate(
    WhisperBridgeContext* ctx,
    const float* samples,
    int n_samples
) {
    return run_whisper(ctx, samples, n_samples, 1);
}

void whisper_bridge_free_result(WhisperBridgeResult* result) {
    if (result) {
        free((void*)result->text);
        free((void*)result->language);
        free(result);
    }
}
