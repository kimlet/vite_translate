#ifndef SENTENCEPIECE_BRIDGE_H
#define SENTENCEPIECE_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct SPBridgeProcessor SPBridgeProcessor;

/// Initialize SentencePiece processor from model file.
/// Returns NULL on failure.
SPBridgeProcessor* sp_bridge_init(const char* model_path);

/// Free the processor.
void sp_bridge_free(SPBridgeProcessor* processor);

/// Encode text to token IDs.
/// @param processor The processor context.
/// @param text The text to encode.
/// @param out_ids Output array of token IDs (caller-allocated, max_length).
/// @param max_length Maximum number of tokens to return.
/// @return Number of tokens written to out_ids, or -1 on error.
int sp_bridge_encode(
    SPBridgeProcessor* processor,
    const char* text,
    int* out_ids,
    int max_length
);

/// Decode token IDs back to text.
/// @param processor The processor context.
/// @param ids Array of token IDs.
/// @param num_ids Number of IDs.
/// @return Decoded text. Caller must call sp_bridge_free_string() after use.
const char* sp_bridge_decode(
    SPBridgeProcessor* processor,
    const int* ids,
    int num_ids
);

/// Free a string returned by sp_bridge_decode.
void sp_bridge_free_string(const char* str);

/// Get the vocabulary size.
int sp_bridge_vocab_size(SPBridgeProcessor* processor);

/// Get the token ID for a piece string (e.g., language code).
int sp_bridge_piece_to_id(SPBridgeProcessor* processor, const char* piece);

#ifdef __cplusplus
}
#endif

#endif // SENTENCEPIECE_BRIDGE_H
