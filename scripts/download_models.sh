#!/bin/bash
# Download models for local development/testing.
# In production, models are downloaded by the app on first run.

set -e

MODELS_DIR="$(dirname "$0")/../assets/models"
mkdir -p "$MODELS_DIR"

echo "=== Downloading whisper ggml-base model ==="
WHISPER_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
WHISPER_FILE="$MODELS_DIR/ggml-base.bin"

if [ ! -f "$WHISPER_FILE" ]; then
    curl -L "$WHISPER_URL" -o "$WHISPER_FILE"
    echo "Downloaded: $WHISPER_FILE"
else
    echo "Already exists: $WHISPER_FILE"
fi

echo ""
echo "=== NLLB model ==="
echo "The NLLB model needs to be converted to CTranslate2 format."
echo "Run scripts/convert_nllb.py to convert and quantize the model."
echo ""
echo "Done!"
