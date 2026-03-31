import 'dart:async';
import 'dart:io';

import '../core/jarvis_voice_config.dart';
import '../data/api/openai_audio_api.dart';
import '../data/models/voice_sidecar_event.dart';
import 'voice_feedback_sounds.dart';
import 'voice_sidecar_client.dart';

enum JarvisPhase {
  scanningWake,
  recordingCommand,
  transcribingCommand,
}

class JarvisWakeSession {
  JarvisWakeSession({
    required this.openAi,
    required VoiceFeedbackSounds feedback,
    required this.onCommandText,
    required this.onError,
    required this.onPhaseChanged,
    required this.shouldBlockScanning,
    VoiceSidecarClient? sidecar,
  })  : _feedback = feedback,
        _sidecar = sidecar ?? VoiceSidecarClient();

  final OpenAiAudioApi openAi;
  final VoiceFeedbackSounds _feedback;
  final VoiceSidecarClient _sidecar;

  final Future<void> Function(String text) onCommandText;
  final void Function(Object e, StackTrace? st) onError;
  final void Function(JarvisPhase phase) onPhaseChanged;
  final bool Function() shouldBlockScanning;

  bool _disposed = false;
  bool _paused = false;
  StreamSubscription<VoiceSidecarEvent>? _eventsSub;

  bool get isPaused => _paused;

  void start() {
    _disposed = false;
    _paused = false;
    unawaited(_startInternal());
  }

  Future<void> stop() async {
    _disposed = true;
    await _eventsSub?.cancel();
    _eventsSub = null;
    await _sidecar.dispose();
  }

  void pauseScanning() {
    _paused = true;
    unawaited(_sidecar.pause());
  }

  void resumeScanning() {
    _paused = false;
    unawaited(_sidecar.resume());
  }

  Future<void> _startInternal() async {
    try {
      await _sidecar.start().timeout(JarvisVoiceConfig.sidecarStartupTimeout);
      onPhaseChanged(JarvisPhase.scanningWake);

      _eventsSub = _sidecar.events.listen((event) {
        unawaited(_handleEvent(event));
      });
    } catch (e, st) {
      if (_disposed) return;
      onError(e, st);
      await Future<void>.delayed(JarvisVoiceConfig.sidecarRestartBackoff);
      if (!_disposed) {
        start();
      }
    }
  }

  Future<void> _handleEvent(VoiceSidecarEvent event) async {
    if (_disposed) return;
    if (_paused) return;

    switch (event.type) {
      case VoiceSidecarEventType.recordingStarted:
      case VoiceSidecarEventType.wakeDetected:
        onPhaseChanged(JarvisPhase.recordingCommand);
        try {
          await _feedback.playRecordingStart();
        } catch (_) {}
        break;
      case VoiceSidecarEventType.recordingStopped:
        try {
          await _feedback.playRecordingEnd();
        } catch (_) {}
        break;
      case VoiceSidecarEventType.commandReady:
        final wav = event.wavPath;
        if (wav == null || wav.isEmpty) return;
        onPhaseChanged(JarvisPhase.transcribingCommand);
        await _transcribeAndDispatch(wav);
        onPhaseChanged(JarvisPhase.scanningWake);
        break;
      case VoiceSidecarEventType.error:
        onError(StateError(event.message ?? 'Error en sidecar de voz'), null);
        break;
      case VoiceSidecarEventType.ready:
      case VoiceSidecarEventType.speechStart:
      case VoiceSidecarEventType.status:
        break;
    }
  }

  Future<void> _transcribeAndDispatch(String wavPath) async {
    if (shouldBlockScanning()) return;
    final f = File(wavPath);
    if (!f.existsSync()) return;
    try {
      final text = await openAi.transcribeWavFile(wavPath);
      if (text.trim().isNotEmpty) {
        await onCommandText(text.trim());
      }
    } catch (e, st) {
      onError(e, st);
    } finally {
      try {
        await f.delete();
      } catch (_) {}
    }
  }
}

