import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import '../data/api/openai_audio_api.dart';

/// Reproduce la respuesta con TTS de OpenAI (MP3) usando **audioplayers**
/// (incluye implementación nativa en Windows; `just_audio` no registraba plugin aquí).
class OpenAiTtsService {
  OpenAiTtsService({required OpenAiAudioApi api}) : _api = api;

  final OpenAiAudioApi _api;
  final AudioPlayer _player = AudioPlayer();

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await stop();
    final bytes = await _api.synthesizeSpeech(text);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/openai_tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
    );
    await file.writeAsBytes(bytes, flush: true);
    await _player.play(DeviceFileSource(file.path));
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
