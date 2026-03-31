import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../../core/errors.dart';
import '../../core/language_codes.dart';

/// Translation service using ONNX Runtime for NLLB model inference
/// and SentencePiece (via FFI) for tokenization.
class TranslationService {
  OrtSession? _encoderSession;
  OrtSession? _decoderSession;
  Pointer<Void>? _spProcessor;
  bool _isInitialized = false;

  // SentencePiece FFI bindings
  late final DynamicLibrary _spLib;
  late final _SpInit _spInit;
  late final _SpFree _spFree;
  late final _SpEncode _spEncode;
  late final _SpDecode _spDecode;
  late final _SpFreeString _spFreeString;
  late final _SpPieceToId _spPieceToId;

  bool get isInitialized => _isInitialized;

  final OnnxRuntime _ort = OnnxRuntime();

  /// Initialize the translation model and tokenizer.
  /// [modelDir] should contain:
  ///   - encoder_model.onnx
  ///   - decoder_model.onnx (or decoder_model_merged.onnx)
  ///   - sentencepiece.bpe.model
  Future<void> initialize(String modelDir) async {
    try {
      // Load SentencePiece native library
      _loadSentencePieceBindings();

      final spModelPath = '$modelDir/sentencepiece.bpe.model';
      final spPathPtr = spModelPath.toNativeUtf8();
      try {
        _spProcessor = _spInit(spPathPtr.cast());
      } finally {
        calloc.free(spPathPtr);
      }

      // Load ONNX encoder and decoder models
      _encoderSession = await _ort.createSession(
        '$modelDir/encoder_model.onnx',
      );
      _decoderSession = await _ort.createSession(
        '$modelDir/decoder_model.onnx',
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint(e.toString());
      throw TranslationException('Failed to initialize translation: $e');
    }
  }

  void _loadSentencePieceBindings() {
    if (Platform.isAndroid) {
      _spLib = DynamicLibrary.open('libsp_bridge.so');
    } else {
      _spLib = DynamicLibrary.process(); // iOS static linking
    }

    _spInit = _spLib.lookupFunction<
      Pointer<Void> Function(Pointer<Utf8>),
      Pointer<Void> Function(Pointer<Utf8>)
    >('sp_bridge_init');

    _spFree = _spLib.lookupFunction<
      Void Function(Pointer<Void>),
      void Function(Pointer<Void>)
    >('sp_bridge_free');

    _spEncode = _spLib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Int32>, Int32),
      int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Int32>, int)
    >('sp_bridge_encode');

    _spDecode = _spLib.lookupFunction<
      Pointer<Utf8> Function(Pointer<Void>, Pointer<Int32>, Int32),
      Pointer<Utf8> Function(Pointer<Void>, Pointer<Int32>, int)
    >('sp_bridge_decode');

    _spFreeString = _spLib.lookupFunction<
      Void Function(Pointer<Utf8>),
      void Function(Pointer<Utf8>)
    >('sp_bridge_free_string');

    _spPieceToId = _spLib.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Utf8>),
      int Function(Pointer<Void>, Pointer<Utf8>)
    >('sp_bridge_piece_to_id');
  }

  /// Tokenize text using SentencePiece.
  List<int> _tokenize(String text) {
    if (_spProcessor == null || _spProcessor == nullptr) return [];

    final textPtr = text.toNativeUtf8();
    final outIds = calloc<Int32>(512); // max 512 tokens

    try {
      final count = _spEncode(_spProcessor!, textPtr, outIds, 512);
      if (count <= 0) return [];

      return List.generate(count, (i) => outIds[i]);
    } finally {
      calloc.free(textPtr);
      calloc.free(outIds);
    }
  }

  /// Detokenize token IDs back to text.
  String _detokenize(List<int> ids) {
    if (_spProcessor == null || _spProcessor == nullptr) return '';

    final idsPtr = calloc<Int32>(ids.length);
    try {
      for (var i = 0; i < ids.length; i++) {
        idsPtr[i] = ids[i];
      }

      final resultPtr = _spDecode(_spProcessor!, idsPtr, ids.length);
      if (resultPtr == nullptr) return '';

      final result = resultPtr.toDartString();
      _spFreeString(resultPtr);
      return result;
    } finally {
      calloc.free(idsPtr);
    }
  }

  /// Get the token ID for a language code (e.g., "eng_Latn").
  int _getLanguageTokenId(String nllbCode) {
    final codePtr = nllbCode.toNativeUtf8();
    try {
      return _spPieceToId(_spProcessor!, codePtr);
    } finally {
      calloc.free(codePtr);
    }
  }

  /// Translate text from source language to target language.
  /// Languages should be Whisper ISO 639-1 codes.
  Future<String> translate(
    String text,
    String srcLangWhisper,
    String tgtLangWhisper,
  ) async {
    if (!_isInitialized) {
      throw TranslationException('Translation service not initialized');
    }

    final srcNllb = LanguageCodes.toNllb(srcLangWhisper);
    final tgtNllb = LanguageCodes.toNllb(tgtLangWhisper);

    if (srcNllb == null || tgtNllb == null) {
      throw TranslationException(
        'Unsupported language pair: $srcLangWhisper -> $tgtLangWhisper',
      );
    }

    // Tokenize: [src_lang_token] + tokens + [eos_token]
    final tokens = _tokenize(text);
    if (tokens.isEmpty) return text;

    final srcLangId = _getLanguageTokenId(srcNllb);
    final tgtLangId = _getLanguageTokenId(tgtNllb);
    const eosTokenId = 2; // NLLB uses 2 as </s>

    // Build encoder input: [src_lang] token1 token2 ... [eos]
    final inputIds = [srcLangId, ...tokens, eosTokenId];
    final attentionMask = List.filled(inputIds.length, 1);

    // Run encoder
    final encoderOutput = await _runEncoder(inputIds, attentionMask);
    if (encoderOutput == null) return text;

    // Autoregressive decoding with decoder
    final outputTokens = await _runDecoder(
      encoderOutput,
      attentionMask,
      tgtLangId,
    );

    // Detokenize output (skip the language token)
    final translatedTokens =
        outputTokens.length > 1 ? outputTokens.sublist(1) : outputTokens;
    // Remove EOS token if present
    final cleanTokens = translatedTokens.where((t) => t != eosTokenId).toList();

    return _detokenize(cleanTokens);
  }

  Future<OrtValue?> _runEncoder(
    List<int> inputIds,
    List<int> attentionMask,
  ) async {
    if (_encoderSession == null) return null;

    try {
      final inputIdsTensor = await OrtValue.fromList(
        inputIds.map((e) => e.toInt()).toList(),
        [1, inputIds.length],
      );

      final attMaskTensor = await OrtValue.fromList(
        attentionMask.map((e) => e.toInt()).toList(),
        [1, attentionMask.length],
      );

      final outputs = await _encoderSession!.run({
        'input_ids': inputIdsTensor,
        'attention_mask': attMaskTensor,
      });

      await inputIdsTensor.dispose();
      await attMaskTensor.dispose();

      // Return the last_hidden_state OrtValue directly
      return outputs.values.first;
    } catch (e) {
      throw TranslationException('Encoder inference failed: $e');
    }
  }

  Future<List<int>> _runDecoder(
    OrtValue encoderOutput,
    List<int> attentionMask,
    int tgtLangId,
  ) async {
    if (_decoderSession == null) return [];

    const maxLength = 256;
    final outputIds = <int>[tgtLangId];
    const eosTokenId = 2;

    try {
      for (var step = 0; step < maxLength; step++) {
        final decoderInputIds = await OrtValue.fromList(
          outputIds.map((e) => e.toInt()).toList(),
          [1, outputIds.length],
        );

        final encoderAttMask = await OrtValue.fromList(
          attentionMask.map((e) => e.toInt()).toList(),
          [1, attentionMask.length],
        );

        final outputs = await _decoderSession!.run({
          'input_ids': decoderInputIds,
          'encoder_attention_mask': encoderAttMask,
          'encoder_hidden_states': encoderOutput,
        });

        await decoderInputIds.dispose();
        await encoderAttMask.dispose();

        // Get logits from output, take argmax of last token
        final logits = outputs.values.first;
        final logitsData = await logits.asFlattenedList();

        if (logitsData.isNotEmpty) {
          // Logits shape: [1, seq_len, vocab_size]
          // We need argmax of the last token's logits
          final vocabSize = logitsData.length ~/ outputIds.length;
          final startIdx = (outputIds.length - 1) * vocabSize;
          final lastTokenLogits = logitsData.sublist(startIdx);

          var maxIdx = 0;
          var maxVal = (lastTokenLogits[0] as num).toDouble();
          for (var i = 1; i < lastTokenLogits.length; i++) {
            final val = (lastTokenLogits[i] as num).toDouble();
            if (val > maxVal) {
              maxVal = val;
              maxIdx = i;
            }
          }

          await logits.dispose();

          if (maxIdx == eosTokenId) break;
          outputIds.add(maxIdx);
        } else {
          await logits.dispose();
          break;
        }
      }
    } catch (e) {
      throw TranslationException('Decoder inference failed: $e');
    }

    return outputIds;
  }

  void dispose() {
    _encoderSession?.close();
    _decoderSession?.close();
    if (_spProcessor != null && _spProcessor != nullptr) {
      _spFree(_spProcessor!);
    }
    _isInitialized = false;
  }
}

// FFI type definitions for SentencePiece
typedef _SpInit = Pointer<Void> Function(Pointer<Utf8>);
typedef _SpFree = void Function(Pointer<Void>);
typedef _SpEncode = int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Int32>, int);
typedef _SpDecode = Pointer<Utf8> Function(Pointer<Void>, Pointer<Int32>, int);
typedef _SpFreeString = void Function(Pointer<Utf8>);
typedef _SpPieceToId = int Function(Pointer<Void>, Pointer<Utf8>);
