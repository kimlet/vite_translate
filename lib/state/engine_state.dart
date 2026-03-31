import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/model_manager.dart';

enum ModelLoadState { notLoaded, loading, loaded, error }

class EngineState {
  final ModelLoadState whisperState;
  final ModelLoadState translationState;
  final double downloadProgress;
  final String? errorMessage;

  const EngineState({
    this.whisperState = ModelLoadState.notLoaded,
    this.translationState = ModelLoadState.notLoaded,
    this.downloadProgress = 0.0,
    this.errorMessage,
  });

  /// App is ready if at least whisper is loaded.
  /// Translation is optional (graceful degradation to transcription-only).
  bool get isReady => whisperState == ModelLoadState.loaded;

  bool get translationReady => translationState == ModelLoadState.loaded;

  bool get isLoading =>
      whisperState == ModelLoadState.loading ||
      translationState == ModelLoadState.loading;

  EngineState copyWith({
    ModelLoadState? whisperState,
    ModelLoadState? translationState,
    double? downloadProgress,
    String? errorMessage,
    bool? clearError,
  }) {
    return EngineState(
      whisperState: whisperState ?? this.whisperState,
      translationState: translationState ?? this.translationState,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage:
          clearError == true ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class EngineNotifier extends StateNotifier<EngineState> {
  final ModelManager _modelManager = ModelManager();

  EngineNotifier() : super(const EngineState());

  ModelManager get modelManager => _modelManager;

  Future<void> checkModelStatus() async {
    final whisperReady = await _modelManager.isWhisperModelReady();
    final nllbReady = await _modelManager.isNllbModelReady();

    state = state.copyWith(
      whisperState:
          whisperReady ? ModelLoadState.loaded : ModelLoadState.notLoaded,
      translationState:
          nllbReady ? ModelLoadState.loaded : ModelLoadState.notLoaded,
    );
  }

  Future<void> downloadModels() async {
    state = state.copyWith(
      whisperState: ModelLoadState.loading,
      translationState: ModelLoadState.loading,
      downloadProgress: 0.0,
    );

    try {
      await _modelManager.downloadWhisperModel(
        onProgress: (p) {
          state = state.copyWith(downloadProgress: p * 0.5);
        },
      );
      state = state.copyWith(whisperState: ModelLoadState.loaded);

      await _modelManager.downloadNllbModel(
        onProgress: (p) {
          state = state.copyWith(downloadProgress: 0.5 + p * 0.5);
        },
      );
      state = state.copyWith(
        translationState: ModelLoadState.loaded,
        downloadProgress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
        whisperState: ModelLoadState.error,
        translationState: ModelLoadState.error,
        errorMessage: e.toString(),
      );
    }
  }

  @override
  void dispose() {
    _modelManager.dispose();
    super.dispose();
  }
}

final engineProvider =
    StateNotifierProvider<EngineNotifier, EngineState>((ref) {
      return EngineNotifier();
    });
