import 'dart:async';
import 'dart:io';

import '../core/jarvis_voice_config.dart';
import '../data/api/openai_audio_api.dart';
import 'voice_feedback_sounds.dart';
import 'voice_recorder_service.dart';

/// Fase de la UI de voz con wake «ok asistente».
enum JarvisPhase {
  /// Buscando la frase en ventanas de audio (Whisper).
  scanningWake,

  /// Tras detectar la frase: grabando el comando hasta silencio o tiempo máximo.
  recordingCommand,

  /// Whisper del comando.
  transcribingCommand,
}

/// Escucha continua: ventanas cortas → Whisper (autoidioma) busca la wake phrase;
/// luego graba el comando con VAD por silencio y pitidos de feedback.
class JarvisWakeSession {
  JarvisWakeSession({
    required this.openAi,
    required this.recorder,
    required VoiceFeedbackSounds feedback,
    required this.onCommandText,
    required this.onError,
    required this.onPhaseChanged,
    required this.shouldBlockScanning,
  }) : _feedback = feedback;

  final OpenAiAudioApi openAi;
  final VoiceRecorderService recorder;
  final VoiceFeedbackSounds _feedback;

  /// Devuelve el texto del comando (Whisper en idioma por defecto de config).
  final Future<void> Function(String text) onCommandText;

  final void Function(Object e, StackTrace? st) onError;
  final void Function(JarvisPhase phase) onPhaseChanged;

  /// Pausa el barrido si el asistente está procesando o hablando por TTS.
  final bool Function() shouldBlockScanning;

  bool _disposed = false;
  bool _paused = false;

  bool get isPaused => _paused;

  /// Inicia el bucle de escucha (permiso de micrófono ya concedido).
  void start() {
    _disposed = false;
    _paused = false;
    unawaited(_idleLoop());
  }

  /// Detiene escucha y cancela grabación activa.
  Future<void> stop() async {
    _disposed = true;
    try {
      await recorder.cancel();
    } catch (_) {}
  }

  /// Pausa el barrido (p. ej. modo manual de grabación).
  void pauseScanning() {
    _paused = true;
  }

  /// Reanuda el barrido tras [pauseScanning].
  void resumeScanning() {
    _paused = false;
  }

  Future<void> _idleLoop() async {
    while (!_disposed) {
      while (_paused && !_disposed) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (_disposed) break;

      while (!_disposed && shouldBlockScanning()) {
        onPhaseChanged(JarvisPhase.scanningWake);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      if (_disposed) break;

      onPhaseChanged(JarvisPhase.scanningWake);

      try {
        final path = await recorder.newRecordingPath();
        await recorder.start(path);

        await _delayWhileRecording(
          const Duration(seconds: JarvisVoiceConfig.wakeScanChunkSeconds),
        );

        if (_disposed) {
          await recorder.cancel();
          break;
        }
        if (_paused) {
          await recorder.cancel();
          continue;
        }

        final stoppedPath = await recorder.stop();
        final wav = stoppedPath ?? path;

        if (!File(wav).existsSync()) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          continue;
        }

        String text;
        try {
          text = await openAi.transcribeWavFile(
            wav,
            language: '',
          );
        } finally {
          try {
            await File(wav).delete();
          } catch (_) {}
        }

        if (_disposed) break;
        if (_paused) continue;

        if (!JarvisVoiceConfig.textContainsWakePhrase(text)) {
          continue;
        }

        await _runCommandPhase();
      } catch (e, st) {
        if (_disposed) break;
        onError(e, st);
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> _delayWhileRecording(Duration total) async {
    final end = DateTime.now().add(total);
    while (DateTime.now().isBefore(end)) {
      if (_disposed || _paused) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _runCommandPhase() async {
    if (_disposed) return;

    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (_disposed || _paused) return;

    onPhaseChanged(JarvisPhase.recordingCommand);

    try {
      await _feedback.playRecordingStart();
    } catch (_) {}

    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (_disposed || _paused) return;

    try {
      final path = await recorder.newRecordingPath();
      await recorder.start(path);

      DateTime? quietSince;
      final started = DateTime.now();
      double? noiseFloorDb;
      double? speechPeakDb;
      var adaptiveThresholdDb = JarvisVoiceConfig.vadFallbackSpeechDb;
      final ampSub = recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        // VAD adaptativo por comando:
        // 1) estima ruido ambiente (noiseFloorDb)
        // 2) estima pico de voz local (speechPeakDb)
        // 3) umbral dinámico entre ambos
        final currentDb = amp.current;
        noiseFloorDb ??= currentDb;
        speechPeakDb ??= currentDb;

        final prevNoise = noiseFloorDb!;
        // Si baja, ajusta rápido (ruido real); si sube, ajusta lento (evita "comerse" la voz).
        noiseFloorDb = currentDb < prevNoise
            ? (prevNoise * 0.65 + currentDb * 0.35)
            : (prevNoise * 0.93 + currentDb * 0.07);

        final prevSpeech = speechPeakDb!;
        // Sube rápido con voz; baja lento para no perder referencia al terminar sílabas.
        speechPeakDb = currentDb > prevSpeech
            ? currentDb
            : (prevSpeech * 0.92 + currentDb * 0.08);

        final dynamicDelta = (speechPeakDb! - noiseFloorDb!) *
            JarvisVoiceConfig.vadThresholdVoiceRatio;
        final clampedDelta = dynamicDelta < JarvisVoiceConfig.vadMinDeltaDb
            ? JarvisVoiceConfig.vadMinDeltaDb
            : dynamicDelta;
        adaptiveThresholdDb = noiseFloorDb! + clampedDelta;
        if (adaptiveThresholdDb > JarvisVoiceConfig.vadMaxThresholdDb) {
          adaptiveThresholdDb = JarvisVoiceConfig.vadMaxThresholdDb;
        }

        final elapsedMs = DateTime.now().difference(started).inMilliseconds;
        final readyForAdaptive = elapsedMs >= JarvisVoiceConfig.vadCalibrationMs;
        final threshold = readyForAdaptive
            ? adaptiveThresholdDb
            : JarvisVoiceConfig.vadFallbackSpeechDb;
        final speech = currentDb >= threshold;
        if (speech) {
          quietSince = null;
        } else {
          quietSince ??= DateTime.now();
        }
      });

      try {
        while (!_disposed && !_paused) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          final now = DateTime.now();
          final elapsed = now.difference(started);

          if (elapsed >=
              const Duration(seconds: JarvisVoiceConfig.maxCommandRecordingSeconds)) {
            break;
          }
          if (elapsed <
              const Duration(milliseconds: JarvisVoiceConfig.minCommandRecordingMs)) {
            continue;
          }
          if (quietSince != null &&
              now.difference(quietSince!) >=
                  const Duration(seconds: JarvisVoiceConfig.commandSilenceSeconds)) {
            break;
          }
        }
      } finally {
        await ampSub.cancel();
      }

      if (_disposed) {
        await recorder.cancel();
        return;
      }
      if (_paused) {
        await recorder.cancel();
        return;
      }

      final outPath = await recorder.stop();
      final wav = outPath ?? path;

      try {
        await _feedback.playRecordingEnd();
      } catch (_) {}

      if (!File(wav).existsSync()) {
        return;
      }

      onPhaseChanged(JarvisPhase.transcribingCommand);

      String commandText;
      try {
        commandText = await openAi.transcribeWavFile(wav);
      } finally {
        try {
          await File(wav).delete();
        } catch (_) {}
      }

      if (_disposed) return;

      final trimmed = commandText.trim();
      if (trimmed.isNotEmpty) {
        await onCommandText(trimmed);
      }
    } catch (e, st) {
      if (!_disposed) {
        onError(e, st);
      }
    } finally {
      if (!_disposed) {
        onPhaseChanged(JarvisPhase.scanningWake);
      }
    }
  }
}
