import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Graba WAV en disco para enviarlo a Whisper (OpenAI).
class VoiceRecorderService {
  VoiceRecorderService() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  String? _currentPath;

  /// Nivel de audio (dBFS) para VAD / silencio; solo mientras graba.
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      _recorder.onAmplitudeChanged(interval);

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<String> newRecordingPath() async {
    final dir = await getTemporaryDirectory();
    _currentPath = '${dir.path}/whisper_${DateTime.now().millisecondsSinceEpoch}.wav';
    return _currentPath!;
  }

  Future<void> start(String path) async {
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
  }

  Future<String?> stop() => _recorder.stop();

  Future<void> cancel() => _recorder.cancel();

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
