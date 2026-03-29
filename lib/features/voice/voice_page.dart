import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../services/openai_tts_service.dart';
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

  bool _recording = false;
  bool _transcribing = false;
  String? _recordingPath;
  String _lastHeard = '';
  String _reply = '';
  String? _intent;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _manualController.dispose();
    unawaited(_tts?.dispose() ?? Future.value());
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _speakOpenAi(String text) async {
    final api = ref.read(openAiAudioApiProvider);
    if (api == null) return;
    _tts ??= OpenAiTtsService(api: api);
    await _tts!.speak(text);
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

  /// Errores de red/backend del asistente (no mezclar con fallos de altavoz/TTS).
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

  Future<void> _toggleRecording() async {
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
        if (text.trim().isNotEmpty) {
          await _sendQuery(text);
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _transcribing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Whisper: $e')),
        );
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

    try {
      final path = await _recorder.newRecordingPath();
      _recordingPath = path;
      await _recorder.start(path);
      if (!mounted) return;
      setState(() => _recording = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo grabar: $e')),
      );
    }
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
            hasOpenAiKey
                ? 'Escuchar para grabar; Detener para transcribir y enviar.'
                : 'Sin OPENAI_API_KEY en .env: no se puede usar el micrófono hasta configurarla.',
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
                  WaveformBars(active: _recording),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: (_loading || _transcribing)
                            ? null
                            : _toggleRecording,
                        icon: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded),
                        label: Text(_recording ? 'Detener' : 'Escuchar'),
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
                        ? 'Grabando…'
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
