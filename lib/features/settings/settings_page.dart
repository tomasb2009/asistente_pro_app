import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../services/openai_tts_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _urlController;
  bool _testing = false;
  String? _healthMessage;
  String? _queryTestReply;
  bool _seededUrl = false;
  String? _openAiTestMessage;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(apiBaseUrlProvider);
    if (!_seededUrl) {
      _urlController.text = current;
      _seededUrl = true;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ajustes',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'URL base del backend (sin barra final).',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'URL base',
              hintText: 'http://127.0.0.1:8000',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () async {
                await ref.read(apiBaseUrlProvider.notifier).setBaseUrl(_urlController.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('URL guardada')),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ),
          const SizedBox(height: 36),
          Text(
            'Voz (Whisper + TTS)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: _testing
                ? null
                : () async {
                    final api = ref.read(openAiAudioApiProvider);
                    if (api == null) {
                      setState(() {
                        _openAiTestMessage =
                            'Falta OPENAI_API_KEY: crea un archivo .env en la raíz del proyecto (o junto al .exe) con OPENAI_API_KEY=sk-...';
                      });
                      return;
                    }
                    setState(() {
                      _testing = true;
                      _openAiTestMessage = null;
                    });
                    try {
                      final tts = OpenAiTtsService(api: api);
                      await tts.speak('Prueba de voz.');
                      if (!context.mounted) return;
                      setState(() {
                        _testing = false;
                        _openAiTestMessage = 'TTS ok.';
                      });
                    } catch (e) {
                      if (!context.mounted) return;
                      setState(() {
                        _testing = false;
                        _openAiTestMessage = 'Error TTS: $e';
                      });
                    }
                  },
            child: const Text('Probar TTS'),
          ),
          if (_openAiTestMessage != null) ...[
            const SizedBox(height: 12),
            Text(_openAiTestMessage!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 32),
          Text(
            'Comprobaciones backend',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.tonal(
                onPressed: _testing
                    ? null
                    : () async {
                        setState(() {
                          _testing = true;
                          _healthMessage = null;
                        });
                        final ok = await ref.read(assistantApiProvider).health();
                        if (!context.mounted) return;
                        setState(() {
                          _testing = false;
                          _healthMessage = ok
                              ? 'GET /health → status ok'
                              : 'No se pudo contactar /health';
                        });
                      },
                child: const Text('Probar /health'),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: _testing
                    ? null
                    : () async {
                        setState(() {
                          _testing = true;
                          _queryTestReply = null;
                        });
                        try {
                          final r = await ref.read(assistantApiProvider).query('hola');
                          if (!context.mounted) return;
                          setState(() {
                            _testing = false;
                            _queryTestReply = r.reply;
                          });
                        } catch (e) {
                          if (!context.mounted) return;
                          setState(() {
                            _testing = false;
                            _queryTestReply = 'Error: $e';
                          });
                        }
                      },
                child: const Text('Probar /api/v1/query'),
              ),
            ],
          ),
          if (_healthMessage != null) ...[
            const SizedBox(height: 12),
            Text(_healthMessage!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (_queryTestReply != null) ...[
            const SizedBox(height: 12),
            Text(_queryTestReply!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wake word',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Opcional: motor dedicado en escritorio. Esta app usa grabación por botón + Whisper.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Valores por defecto: base ${AppConfig.defaultBaseUrl}, timeout consulta ${AppConfig.queryTimeoutSeconds}s.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary.withValues(alpha: 0.85),
                ),
          ),
        ],
      ),
    );
  }
}
