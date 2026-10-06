import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  SpeechService({SpeechToText? plugin}) : _speech = plugin ?? SpeechToText();

  static final SpeechService instance = SpeechService();

  final SpeechToText _speech;
  var _ready = false;
  String lastError = '';

  bool get isListening => _speech.isListening;

  Future<bool> ensureReady() async {
    lastError = '';
    if (kIsWeb) {
      lastError = 'ブラウザでは音声入力を後回しにしています。文字で入力してください。';
      return false;
    }
    if (_ready && _speech.isAvailable) return true;
    try {
      _ready = await _speech.initialize(
        onError: (error) => lastError = error.errorMsg,
        onStatus: (_) {},
      );
      if (!_ready) {
        lastError = 'この端末では音声入力に対応していません。文字で入力してください。';
      }
    } catch (_) {
      _ready = false;
      lastError = 'この端末では音声入力に対応していません。文字で入力してください。';
    }
    return _ready;
  }

  Future<String> listenOnce({
    void Function(String partial)? onPartial,
    Duration listenFor = const Duration(seconds: 20),
    Duration pauseFor = const Duration(seconds: 2),
  }) async {
    final ready = await ensureReady();
    if (!ready) {
      throw StateError(lastError);
    }

    final completer = Completer<String>();
    var latest = '';

    await _speech.listen(
      onResult: (result) {
        latest = result.recognizedWords.trim();
        onPartial?.call(latest);
        if (result.finalResult && !completer.isCompleted) {
          completer.complete(latest);
        }
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        partialResults: true,
        cancelOnError: true,
        localeId: 'ja_JP',
        listenFor: listenFor,
        pauseFor: pauseFor,
        contextualPhrases: const [
          '予定',
          '円',
          'タイマー',
          '日記',
          '共有',
          'ポモドーロ',
        ],
      ),
    );

    try {
      final text = await completer.future.timeout(
        listenFor + const Duration(seconds: 5),
        onTimeout: () => latest,
      );
      return text;
    } finally {
      await stop();
    }
  }

  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
  }

  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } catch (_) {}
  }
}
