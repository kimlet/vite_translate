import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// Native types
typedef WhisperBridgeContextNative = Void;

final class WhisperBridgeResult extends Struct {
  external Pointer<Utf8> text;
  external Pointer<Utf8> language;

  @Float()
  external double languageProbability;
}

// C function signatures
typedef _InitNative = Pointer<WhisperBridgeContextNative> Function(Pointer<Utf8>);
typedef _InitDart = Pointer<WhisperBridgeContextNative> Function(Pointer<Utf8>);

typedef _FreeNative = Void Function(Pointer<WhisperBridgeContextNative>);
typedef _FreeDart = void Function(Pointer<WhisperBridgeContextNative>);

typedef _TranscribeNative = Pointer<WhisperBridgeResult> Function(
  Pointer<WhisperBridgeContextNative>, Pointer<Float>, Int32, Int32,
);
typedef _TranscribeDart = Pointer<WhisperBridgeResult> Function(
  Pointer<WhisperBridgeContextNative>, Pointer<Float>, int, int,
);

typedef _TranslateNative = Pointer<WhisperBridgeResult> Function(
  Pointer<WhisperBridgeContextNative>, Pointer<Float>, Int32,
);
typedef _TranslateDart = Pointer<WhisperBridgeResult> Function(
  Pointer<WhisperBridgeContextNative>, Pointer<Float>, int,
);

typedef _FreeResultNative = Void Function(Pointer<WhisperBridgeResult>);
typedef _FreeResultDart = void Function(Pointer<WhisperBridgeResult>);

class WhisperBindings {
  late final DynamicLibrary _lib;
  late final _InitDart _init;
  late final _FreeDart _free;
  late final _TranscribeDart _transcribe;
  late final _TranslateDart _translate;
  late final _FreeResultDart _freeResult;

  WhisperBindings() {
    _lib = _loadLibrary();
    _init = _lib.lookupFunction<_InitNative, _InitDart>('whisper_bridge_init');
    _free = _lib.lookupFunction<_FreeNative, _FreeDart>('whisper_bridge_free');
    _transcribe = _lib.lookupFunction<_TranscribeNative, _TranscribeDart>(
      'whisper_bridge_transcribe',
    );
    _translate = _lib.lookupFunction<_TranslateNative, _TranslateDart>(
      'whisper_bridge_translate',
    );
    _freeResult = _lib.lookupFunction<_FreeResultNative, _FreeResultDart>(
      'whisper_bridge_free_result',
    );
  }

  Pointer<WhisperBridgeContextNative> init(Pointer<Utf8> p) => _init(p);
  void free(Pointer<WhisperBridgeContextNative> p) => _free(p);
  Pointer<WhisperBridgeResult> transcribe(
    Pointer<WhisperBridgeContextNative> c, Pointer<Float> s, int n, int d,
  ) => _transcribe(c, s, n, d);
  Pointer<WhisperBridgeResult> translate(
    Pointer<WhisperBridgeContextNative> c, Pointer<Float> s, int n,
  ) => _translate(c, s, n);
  void freeResult(Pointer<WhisperBridgeResult> p) => _freeResult(p);

  static DynamicLibrary _loadLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libwhisper_bridge.so');
    } else if (Platform.isIOS) {
      return DynamicLibrary.process();
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }
}
