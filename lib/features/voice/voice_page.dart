import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../services/jarvis_wake_session.dart';
import '../../services/openai_tts_service.dart';
import '../../services/voice_feedback_sounds.dart';
import '../../services/voice_recorder_service.dart';
import 'widgets/waveform_bars.dart';

class VoicePage extends ConsumerStatefulWidget {
  const VoicePage({super.key});

  @override
  ConsumerState<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends ConsumerState<VoicePage> {
  final _manualController = TextEditingController();
  final _recorder = VoiceRecorderService();

  OpenAiTtsService? _tts;
  VoiceFeedbackSounds? _feedbackSounds;
  JarvisWakeSession? _jarvis;

  JarvisPhase _jarvisPhase = JarvisPhase.scanningWake;

  bool _recording = false;
  bool _transcribing = false;
  String? _recordingPath;
  String _lastHeard = '';
  String _reply = '';
  String? _intent;
  bool _loading = false;
  bool _ttsPlaying = false;
  String? _error;
  ProviderSubscription<String?>? _openAiKeySub;

  @override
  void dispose() {
    _manualController.dispose();
    _openAiKeySub?.close();
    unawaited(_disposeJarvis());
    unawaited(_tts?.dispose() ?? Future.value());
    unawaited(_recorder.dispose());
    super.dispose();
  }

  Future<void> _disposeJarvis() async {
    await _jarvis?.stop();
    await _feedbackSounds?.dispose();
    _jarvis = null;
    _feedbackSounds = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startJarvisIfPossible());
    _openAiKeySub = ref.listenManual<String?>(
      openAiApiKeyProvider,
      (prev, next) {
        final had = (prev ?? '').isNotEmpty;
        final has = (next ?? '').isNotEmpty;
        if (!had && has) {
          _startJarvisIfPossible();
        } else if (had && !has) {
          unawaited(_disposeJarvis().then((_) {
            if (mounted) setState(() => _jarvisPhase = JarvisPhase.scanningWake);
          }));
        }
      },
    );
  }

  Future<void> _startJarvisIfPossible() async {
    final openAi = ref.read(openAiAudioApiProvider);
    if (openAi == null || !mounted) return;
    final ok = await _recorder.hasPermission();
    if (!ok || !mounted) return;

    await _disposeJarvis();
    _feedbackSounds = VoiceFeedbackSounds();
    _jarvis = JarvisWakeSession(
      openAi: openAi,
      recorder: _recorder,
      feedback: _feedbackSounds!,
      onCommandText: (t) => _sendQuery(t),
      onError: (e, st) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Voz: $e')),
        );
      },
      onPhaseChanged: (p) {
        if (mounted) setState(() => _jarvisPhase = p);
      },
      shouldBlockScanning: () => _loading || _transcribing || _ttsPlaying,
    );
    _jarvis!.start();
    if (mounted) setState(() {});
  }

  Future<void> _speakOpenAi(String text) async {
    final api = ref.read(openAiAudioApiProvider);
    if (api == null) return;
    _tts ??= OpenAiTtsService(api: api);
    setState(() => _ttsPlaying = true);
    try {
      await _tts!.speak(text);
    } finally {
      if (mounted) setState(() => _ttsPlaying = false);
    }
  }

  Future<void> _repeatAudio() async {
    if (_reply.isEmpty) return;
    try {
      await _speakOpenAi(_reply);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audio: $e')),
        );
      }
    }
  }

  Future<void> _sendQuery(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _reply = '';
      _intent = null;
    });
    try {
      final api = ref.read(assistantApiProvider);
      final res = await api.query(trimmed);
      if (!mounted) return;
      setState(() {
        _reply = res.reply;
        _intent = res.intent;
        _loading = false;
      });
      try {
        await _speakOpenAi(res.reply);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo reproducir el audio (TTS): $e'),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Grabación manual sin wake phrase (pausa el barrido de «ok asistente»).
  Future<void> _toggleManualRecording() async {
    if (_loading || _transcribing) return;

    final openAi = ref.read(openAiAudioApiProvider);
    if (openAi == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Falta OPENAI_API_KEY: define OPENAI_API_KEY en el archivo .env (raíz del proyecto o junto al .exe).',
          ),
        ),
      );
      return;
    }

    if (_recording) {
      _jarvis?.pauseScanning();
      setState(() => _recording = false);
      setState(() => _transcribing = true);
      try {
        final path = await _recorder.stop() ?? _recordingPath;
        _recordingPath = null;
        if (path == null || !File(path).existsSync()) {
          throw StateError('No se pudo guardar el audio.');
        }
        final text = await openAi.transcribeWavFile(path);
        if (!mounted) return;
        setState(() {
          _lastHeard = text;
          _transcribing = false;
        });
        try {
          await File(path).delete();
        } catch (_) {}
        if (text.trim().isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Whisper no captó texto. Habla más cerca del micrófono o sube el volumen de entrada.',
                ),
              ),
            );
          }
        } else {
          await _sendQuery(text);
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _transcribing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Whisper: $e')),
        );
      } finally {
        _jarvis?.resumeScanning();
      }
      return;
    }

    final ok = await _recorder.hasPermission();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permiso de micrófono denegado.'),
        ),
      );
      return;
    }

    _jarvis?.pauseScanning();
    try {
      final path = await _recorder.newRecordingPath();
      _recordingPath = path;
      await _recorder.start(path);
      if (!mounted) return;
      setState(() => _recording = true);
    } catch (e) {
      _jarvis?.resumeScanning();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo grabar: $e')),
      );
    }
  }

  String _statusLine(bool hasKey) {
    if (!hasKey) {
      return 'Sin OPENAI_API_KEY en .env: no hay voz por micrófono.';
    }
    if (_recording) {
      return 'Modo manual: grabando… pulsa Detener para transcribir.';
    }
    switch (_jarvisPhase) {
      case JarvisPhase.scanningWake:
        return 'Escuchando siempre. Di «ok asistente» y luego tu mensaje. Se envía tras ~2 s de silencio o al límite de tiempo.';
      case JarvisPhase.recordingCommand:
        return 'Frase detectada: grabando tu mensaje…';
      case JarvisPhase.transcribingCommand:
        return 'Transcribiendo comando…';
    }
  }

  bool get _waveActive {
    if (_recording) return true;
    if (_jarvis == null) return false;
    return _jarvisPhase == JarvisPhase.recordingCommand ||
        _jarvisPhase == JarvisPhase.scanningWake;
  }

  bool get _jarvisMicBusy {
    return _jarvisPhase == JarvisPhase.recordingCommand ||
        _jarvisPhase == JarvisPhase.transcribingCommand;
  }

  @override
  Widget build(BuildContext context) {
    final hasOpenAiKey = (ref.watch(openAiApiKeyProvider) ?? '').isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Hablar',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _statusLine(hasOpenAiKey),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: hasOpenAiKey
                      ? AppTheme.textSecondary
                      : Colors.orangeAccent,
                ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WaveformBars(active: _waveActive),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: (_loading ||
                                _transcribing ||
                                (_jarvisMicBusy && !_recording))
                            ? null
                            : _toggleManualRecording,
                        icon: Icon(
                          _recording ? Icons.stop_rounded : Icons.mic_none_rounded,
                        ),
                        label: Text(_recording ? 'Detener' : 'Modo manual'),
                      ),
                      const SizedBox(width: 12),
                      if (_transcribing)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text('Transcribiendo con Whisper…'),
                        ),
                      if (_intent != null)
                        Chip(
                          label: Text('intent: $_intent'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Entendido (Whisper)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _recording
                        ? 'Grabando (manual)…'
                        : (_lastHeard.isEmpty ? '—' : _lastHeard),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Respuesta',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.redAccent))
                  else if (_loading)
                    const LinearProgressIndicator(minHeight: 2)
                  else
                    Text(
                      _reply.isEmpty ? '—' : _reply,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _reply.isEmpty ? null : _repeatAudio,
                        icon: const Icon(Icons.volume_up_rounded),
                        label: const Text('Repetir'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => unawaited(_tts?.stop() ?? Future.value()),
                        icon: const Icon(Icons.volume_off_rounded),
                        label: const Text('Silenciar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'O escribe el mensaje',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _manualController,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Pregunta al asistente…',
            ),
            onSubmitted: (_) => _sendQuery(_manualController.text),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _loading ? null : () => _sendQuery(_manualController.text),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Enviar'),
            ),
          ),
        ],
      ),
    );
  }
}
