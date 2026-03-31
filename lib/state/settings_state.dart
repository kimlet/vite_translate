import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final String primaryLanguageCode;
  final bool onboardingComplete;
  final bool modelsDownloaded;
  final int sampleRate; // 8000 or 16000

  const SettingsState({
    this.primaryLanguageCode = 'en',
    this.onboardingComplete = false,
    this.modelsDownloaded = false,
    this.sampleRate = 16000,
  });

  SettingsState copyWith({
    String? primaryLanguageCode,
    bool? onboardingComplete,
    bool? modelsDownloaded,
    int? sampleRate,
  }) {
    return SettingsState(
      primaryLanguageCode: primaryLanguageCode ?? this.primaryLanguageCode,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      modelsDownloaded: modelsDownloaded ?? this.modelsDownloaded,
      sampleRate: sampleRate ?? this.sampleRate,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      primaryLanguageCode: prefs.getString('primaryLanguage') ?? 'en',
      onboardingComplete: prefs.getBool('onboardingComplete') ?? false,
      modelsDownloaded: prefs.getBool('modelsDownloaded') ?? false,
      sampleRate: prefs.getInt('sampleRate') ?? 16000,
    );
  }

  Future<void> setPrimaryLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('primaryLanguage', code);
    state = state.copyWith(primaryLanguageCode: code);
  }

  Future<void> setOnboardingComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', value);
    state = state.copyWith(onboardingComplete: value);
  }

  Future<void> setModelsDownloaded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('modelsDownloaded', value);
    state = state.copyWith(modelsDownloaded: value);
  }

  Future<void> setSampleRate(int rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sampleRate', rate);
    state = state.copyWith(sampleRate: rate);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
      return SettingsNotifier();
    });
