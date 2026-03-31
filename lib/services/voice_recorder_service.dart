import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Grabación manual WAV para enviarlo a Whisper (fallback al modo sidecar).
class VoiceRecorderService {
  VoiceRecorderService() : _recorder = AudioRecorder();

  AudioRecorder _recorder;
  String? _currentPath;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<String> newRecordingPath() async {
    final dir = await getTemporaryDirectory();
    _currentPath = '${dir.path}/whisper_${DateTime.now().millisecondsSinceEpoch}.wav';
    return _currentPath!;
  }

  Future<void> start(String path) async {
    try {
      if (await _recorder.isRecording() || await _recorder.isPaused()) {
        await _recorder.stop();
      }
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
    } on StateError {
      await _recreateRecorder();
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
    }
  }

  Future<String?> stop() async {
    try {
      if (!await _recorder.isRecording() && !await _recorder.isPaused()) {
        return _currentPath;
      }
      return _recorder.stop();
    } on StateError {
      await _recreateRecorder();
      return _currentPath;
    }
  }

  Future<void> cancel() async {
    try {
      if (!await _recorder.isRecording() && !await _recorder.isPaused()) return;
      await _recorder.cancel();
    } on StateError {
      await _recreateRecorder();
    }
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }

  Future<void> _recreateRecorder() async {
    try {
      await _recorder.dispose();
    } catch (_) {}
    _recorder = AudioRecorder();
  }
}

