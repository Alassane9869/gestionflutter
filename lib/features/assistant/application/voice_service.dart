import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'assistant_service.dart';

class VoiceState {
  final bool isListening;
  final String lastWords;
  final String error;
  final bool isAvailable;

  VoiceState({
    this.isListening = false,
    this.lastWords = '',
    this.error = '',
    this.isAvailable = false,
  });

  VoiceState copyWith({
    bool? isListening,
    String? lastWords,
    String? error,
    bool? isAvailable,
  }) {
    return VoiceState(
      isListening: isListening ?? this.isListening,
      lastWords: lastWords ?? this.lastWords,
      error: error ?? this.error,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

final voiceServiceProvider = NotifierProvider<VoiceService, VoiceState>(() {
  return VoiceService();
});

class VoiceService extends Notifier<VoiceState> {
  final SpeechToText _speech = SpeechToText();

  @override
  VoiceState build() {
    _initSpeech();
    return VoiceState();
  }

  Future<void> _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (kDebugMode) print('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            state = state.copyWith(isListening: false);
          }
        },
        onError: (errorNotification) {
          if (kDebugMode) print('Speech error: $errorNotification');
          state = state.copyWith(
            error: errorNotification.errorMsg,
            isListening: false,
          );
        },
      );
      state = state.copyWith(isAvailable: available);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isAvailable: false);
    }
  }

  void toggleListening() async {
    if (!state.isAvailable) {
      await _initSpeech();
      if (!state.isAvailable) {
        ref.read(assistantProvider.notifier).addAssistantMessage(
          "🚨 **Erreur Micro (Windows)** :\n\n"
          "L'assistant n'arrive pas à accéder à votre microphone. Veuillez vérifier :\n"
          "1. **Paramètres Windows** > Confidentialité > Microphone : **Activé**.\n"
          "2. **Paramètres Windows** > Confidentialité > Voix : **Reconnaissance vocale en ligne activée**.\n"
          "3. Vérifiez qu'un microphone est branché et défini par défaut.\n\n"
          "En attendant, vous pouvez utiliser le **clavier** pour commander l'IA. ⌨️"
        );
        return;
      }
    }
    
    if (state.isListening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  Future<void> startListening() async {
    if (!state.isAvailable) {
      await _initSpeech();
      if (!state.isAvailable) return;
    }

    state = state.copyWith(isListening: true, lastWords: '', error: '');
    
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        state = state.copyWith(lastWords: result.recognizedWords);
        if (result.finalResult) {
          _processVoiceCommand(result.recognizedWords);
        }
      },
      localeId: 'fr_FR',
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
        listenMode: ListenMode.confirmation,
      ),
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
    state = state.copyWith(isListening: false);
  }

  void _processVoiceCommand(String words) {
    if (words.isEmpty) return;
    
    ref.read(assistantProvider.notifier).sendMessage(words);
  }
}
