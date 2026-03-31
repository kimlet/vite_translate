#ifndef CT2_BRIDGE_H
#define CT2_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct CT2BridgeTranslator CT2BridgeTranslator;

/// Initialize CTranslate2 translator from model directory.
/// Returns NULL on failure.
CT2BridgeTranslator* ct2_bridge_init(const char* model_dir);

/// Free the translator.
void ct2_bridge_free(CT2BridgeTranslator* translator);

/// Translate text from source language to target language.
/// @param translator The CTranslate2 translator context.
/// @param text The text to translate.
/// @param source_lang NLLB source language code (e.g., "eng_Latn").
/// @param target_lang NLLB target language code (e.g., "spa_Latn").
/// @return Translated text. Caller must call ct2_bridge_free_result() after use.
const char* ct2_bridge_translate(
    CT2BridgeTranslator* translator,
    const char* text,
    const char* source_lang,
    const char* target_lang
);

/// Free a translation result string.
void ct2_bridge_free_result(const char* result);

#ifdef __cplusplus
}
#endif

#endif // CT2_BRIDGE_H
