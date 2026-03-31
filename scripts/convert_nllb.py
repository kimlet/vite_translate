#!/usr/bin/env python3
"""
Convert NLLB-200-distilled-600M from HuggingFace to CTranslate2 int8 format.

Prerequisites:
    pip install ctranslate2 transformers sentencepiece

Usage:
    python convert_nllb.py [--output_dir ../assets/models/nllb-200-distilled-600M-ct2-int8]
"""

import argparse
import os

def main():
    parser = argparse.ArgumentParser(
        description="Convert NLLB model to CTranslate2 format"
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
            "nllb-200-distilled-600M-ct2-int8",
        ),
        help="Output directory for CTranslate2 model",
    )
    parser.add_argument(
        "--quantization",
        default="int8",
        choices=["int8", "int16", "float16", "float32"],
        help="Quantization type",
    )
    args = parser.parse_args()

    try:
        import ctranslate2
    except ImportError:
        print("Please install ctranslate2: pip install ctranslate2")
        return

    print(f"Converting {args.model_name} to CTranslate2 {args.quantization} format...")
    print(f"Output: {args.output_dir}")

    converter = ctranslate2.converters.TransformersConverter(args.model_name)
    converter.convert(
        args.output_dir,
        quantization=args.quantization,
        force=True,
    )

    print(f"\nDone! Model saved to: {args.output_dir}")
    print(f"You can now use this model directory in the app.")


if __name__ == "__main__":
    main()
