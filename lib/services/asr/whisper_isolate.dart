import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../../models/transcription_result.dart';
import 'whisper_service.dart';

/// Runs whisper inference in a separate Dart isolate to avoid blocking the UI.
class WhisperIsolate {
  Isolate? _isolate;
  SendPort? _sendPort;
  final _responseCompleter = <int, Completer<TranscriptionResult>>{};
  int _requestId = 0;

  bool get isInitialized => _sendPort != null;

  /// Spawn the isolate and initialize the whisper model.
  Future<void> initialize(String modelPath) async {
    final receivePort = ReceivePort();

    _isolate = await Isolate.spawn(
      _isolateEntry,
      _IsolateInitMessage(receivePort.sendPort, modelPath),
    );

    final completer = Completer<SendPort>();

    receivePort.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else if (message is _IsolateResponse) {
        final pending = _responseCompleter.remove(message.requestId);
        if (pending != null) {
          if (message.error != null) {
            pending.completeError(Exception(message.error));
          } else {
            pending.complete(message.result);
          }
        }
      }
    });

    _sendPort = await completer.future;
  }

  /// Transcribe audio samples in the background isolate.
  Future<TranscriptionResult> transcribe(
    Float32List samples, {
    bool isPartial = false,
  }) {
    if (_sendPort == null) {
      throw StateError('WhisperIsolate not initialized');
    }

    final id = _requestId++;
    final completer = Completer<TranscriptionResult>();
    _responseCompleter[id] = completer;

    _sendPort!.send(_IsolateRequest(
      requestId: id,
      samples: samples,
      isPartial: isPartial,
    ));

    return completer.future;
  }

  void dispose() {
    _isolate?.kill();
    _isolate = null;
    _sendPort = null;
    for (final completer in _responseCompleter.values) {
      completer.completeError(StateError('Isolate disposed'));
    }
    _responseCompleter.clear();
  }

  static void _isolateEntry(_IsolateInitMessage init) {
    final service = WhisperService();
    service.initialize(init.modelPath);

    final receivePort = ReceivePort();
    init.sendPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      if (message is _IsolateRequest) {
        try {
          final result = service.transcribe(
            message.samples,
            isPartial: message.isPartial,
          );
          init.sendPort.send(_IsolateResponse(
            requestId: message.requestId,
            result: result,
          ));
        } catch (e) {
          init.sendPort.send(_IsolateResponse(
            requestId: message.requestId,
            error: e.toString(),
          ));
        }
      }
    });
  }
}

class _IsolateInitMessage {
  final SendPort sendPort;
  final String modelPath;
  _IsolateInitMessage(this.sendPort, this.modelPath);
}

class _IsolateRequest {
  final int requestId;
  final Float32List samples;
  final bool isPartial;
  _IsolateRequest({
    required this.requestId,
    required this.samples,
    required this.isPartial,
  });
}

class _IsolateResponse {
  final int requestId;
  final TranscriptionResult? result;
  final String? error;
  _IsolateResponse({required this.requestId, this.result, this.error});
}
