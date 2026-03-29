import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'windows_beep.dart' if (dart.library.html) 'windows_beep_stub.dart';

/// Pitidos al iniciar y terminar la grabación del comando (después del wake).
/// En Windows: [windowsBeep] (kernel32) para que se oiga con el mic activo.
/// Otros: WAV en memoria vía [BytesSource].
class VoiceFeedbackSounds {
  VoiceFeedbackSounds() : _player = AudioPlayer();

  final AudioPlayer _player;

  Future<void> playRecordingStart() async {
    await _playFeedback(high: true);
  }

  Future<void> playRecordingEnd() async {
    await _playFeedback(high: false);
  }

  Future<void> dispose() async {
    await _player.dispose();
  }

  Future<void> _playFeedback({required bool high}) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      windowsBeep(high ? 1200 : 600, high ? 140 : 160);
      await Future<void>.delayed(Duration(milliseconds: high ? 50 : 60));
      return;
    }
    await _playToneWav(frequency: high ? 880 : 440, durationMs: 100);
  }

  Future<void> _playToneWav({
    required double frequency,
    required int durationMs,
  }) async {
    const sampleRate = 44100;
    final n = sampleRate * durationMs ~/ 1000;
    final samples = Int16List(n);
    const volume = 0.42;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final v = volume * 32767.0 * math.sin(2 * math.pi * frequency * t);
      samples[i] = v.round().clamp(-32767, 32767);
    }
    final bytes = _pcm16MonoWav(samples: samples, sampleRate: sampleRate);
    await _player.stop();
    await _player.play(BytesSource(bytes, mimeType: 'audio/wav'));
    await _player.onPlayerComplete.first;
  }

  Uint8List _pcm16MonoWav({
    required Int16List samples,
    required int sampleRate,
  }) {
    final dataSize = samples.length * 2;
    final out = BytesBuilder();
    void writeString(String s) {
      for (var i = 0; i < s.length; i++) {
        out.addByte(s.codeUnitAt(i));
      }
    }

    writeString('RIFF');
    out.add(_le32(36 + dataSize));
    writeString('WAVE');
    writeString('fmt ');
    out.add(_le32(16));
    out.add(_le16(1));
    out.add(_le16(1));
    out.add(_le32(sampleRate));
    out.add(_le32(sampleRate * 2));
    out.add(_le16(2));
    out.add(_le16(16));
    writeString('data');
    out.add(_le32(dataSize));
    final bd = ByteData(samples.length * 2);
    for (var i = 0; i < samples.length; i++) {
      bd.setInt16(i * 2, samples[i], Endian.little);
    }
    out.add(bd.buffer.asUint8List());
    return out.takeBytes();
  }

  List<int> _le16(int v) {
    final b = ByteData(2)..setInt16(0, v, Endian.little);
    return b.buffer.asUint8List();
  }

  List<int> _le32(int v) {
    final b = ByteData(4)..setInt32(0, v, Endian.little);
    return b.buffer.asUint8List();
  }
}
