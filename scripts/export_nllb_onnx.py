#!/usr/bin/env python3
"""
Export NLLB-200-distilled-600M to ONNX format for mobile inference.

Prerequisites:
    pip install optimum[exporters] transformers sentencepiece

Usage:
    python export_nllb_onnx.py [--output_dir ../assets/models/nllb-onnx]

This produces:
    - encoder_model.onnx (~600MB, quantize to ~300MB with int8)
    - decoder_model.onnx
    - sentencepiece.bpe.model (tokenizer)
"""

import argparse
import os
import shutil


def main():
    parser = argparse.ArgumentParser(
        description="Export NLLB model to ONNX format"
    )
    parser.add_argument(
        "--model_name",
        default="facebook/nllb-200-distilled-600M",
        help="HuggingFace model name",
    )
    parser.add_argument(
        "--output_dir",
        default=os.path.join(
            os.path.dirname(__file__),
            "..",
            "assets",
            "models",
            "nllb-onnx",
        ),
        help="Output directory for ONNX model",
    )
    parser.add_argument(
        "--quantize",
        action="store_true",
        default=True,
        help="Quantize to int8 (default: True)",
    )
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)

    print(f"Exporting {args.model_name} to ONNX format...")
    print(f"Output: {args.output_dir}")

    try:
        from optimum.exporters.onnx import main_export
    except ImportError:
        print("Please install optimum: pip install optimum[exporters]")
        return

    # Export encoder and decoder separately
    main_export(
        args.model_name,
        args.output_dir,
        task="translation",
        opset=14,
    )

    if args.quantize:
        print("Quantizing to int8...")
        try:
            from optimum.onnxruntime import ORTQuantizer
            from optimum.onnxruntime.configuration import AutoQuantizationConfig

            qconfig = AutoQuantizationConfig.avx512_vnni(is_static=False)

            for model_name in ["encoder_model.onnx", "decoder_model.onnx"]:
                model_path = os.path.join(args.output_dir, model_name)
                if os.path.exists(model_path):
                    quantizer = ORTQuantizer.from_pretrained(
                        args.output_dir, file_name=model_name
                    )
                    quantizer.quantize(
                        save_dir=args.output_dir,
                        quantization_config=qconfig,
                    )
                    print(f"  Quantized: {model_name}")
        except ImportError:
            print("Warning: Could not quantize. Install onnxruntime for quantization.")

    # Copy the tokenizer model
    try:
        from transformers import AutoTokenizer

        tokenizer = AutoTokenizer.from_pretrained(args.model_name)
        tokenizer.save_pretrained(args.output_dir)
        print("Tokenizer saved.")

        # Also copy the sentencepiece model directly
        sp_model = os.path.join(args.output_dir, "sentencepiece.bpe.model")
        if not os.path.exists(sp_model):
            # The tokenizer files include the SP model
            for f in os.listdir(args.output_dir):
                if f.endswith(".model") and "sentencepiece" in f.lower():
                    print(f"  SentencePiece model: {f}")
    except Exception as e:
        print(f"Warning: Could not save tokenizer: {e}")

    print(f"\nDone! Model saved to: {args.output_dir}")
    print("Files needed on device:")
    for f in sorted(os.listdir(args.output_dir)):
        size = os.path.getsize(os.path.join(args.output_dir, f))
        print(f"  {f} ({size / 1024 / 1024:.1f} MB)")


if __name__ == "__main__":
    main()
