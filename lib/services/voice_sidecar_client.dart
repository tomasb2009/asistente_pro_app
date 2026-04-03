import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../core/jarvis_voice_config.dart';
import '../data/models/voice_sidecar_event.dart';

class VoiceSidecarClient {
  VoiceSidecarClient();

  Process? _proc;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  final _eventsCtrl = StreamController<VoiceSidecarEvent>.broadcast();

  bool get isRunning => _proc != null;
  Stream<VoiceSidecarEvent> get events => _eventsCtrl.stream;

  Future<void> start() async {
    if (_proc != null) return;

    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      throw UnsupportedError(
        'El sidecar de wake word (proceso nativo) no está disponible en esta plataforma. '
        'En móvil usa «Modo manual» o escribe el mensaje.',
      );
    }

    final launch = await _resolveLaunch();
    final proc = await Process.start(
      launch.exec,
      launch.args,
      workingDirectory: launch.cwd,
      mode: ProcessStartMode.normal,
      runInShell: false,
    );
    _proc = proc;

    _stdoutSub = proc.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleStdout);
    _stderrSub = proc.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      // Las librerías de Python escriben avisos en stderr; no son fallos IPC.
      // Solo los JSON con event "error" en stdout deben tratarse como error.
      if (kDebugMode) {
        debugPrint('[voice_sidecar] $line');
      }
      _eventsCtrl.add(
        VoiceSidecarEvent(
          type: VoiceSidecarEventType.status,
          rawType: 'stderr',
          message: line,
          meta: const {},
        ),
      );
    });

    unawaited(
      proc.exitCode.then((code) {
        _eventsCtrl.add(
          VoiceSidecarEvent(
            type: VoiceSidecarEventType.status,
            rawType: 'exit',
            message: 'sidecar exit code=$code',
            meta: {'exit_code': code},
          ),
        );
        _proc = null;
      }),
    );

    await sendCommand('start', {
      'wake_phrase': JarvisVoiceConfig.wakePhrase,
      'sample_rate_hz': JarvisVoiceConfig.sampleRateHz,
      'frame_ms': JarvisVoiceConfig.frameMs,
      'command_silence_ms': JarvisVoiceConfig.commandSilenceMs,
      'max_command_ms': JarvisVoiceConfig.maxCommandMs,
      'pre_roll_ms': JarvisVoiceConfig.preRollMs,
      'post_roll_ms': JarvisVoiceConfig.postRollMs,
      'enable_rnnoise': JarvisVoiceConfig.enableRnnoise,
      'enable_webrtc_vad': JarvisVoiceConfig.enableWebRtcVad,
    });
  }

  Future<void> pause() => sendCommand('pause', const {});
  Future<void> resume() => sendCommand('resume', const {});

  Future<void> stop() async {
    final proc = _proc;
    if (proc == null) return;
    await sendCommand('stop', const {});
    try {
      await proc.exitCode.timeout(JarvisVoiceConfig.sidecarShutdownTimeout);
    } catch (_) {
      proc.kill(ProcessSignal.sigterm);
      await proc.exitCode.timeout(const Duration(seconds: 1), onTimeout: () {
        proc.kill(ProcessSignal.sigkill);
        return -1;
      });
    }
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
    _proc = null;
  }

  Future<void> dispose() async {
    await stop();
    await _eventsCtrl.close();
  }

  Future<void> sendCommand(String command, Map<String, dynamic> payload) async {
    final proc = _proc;
    if (proc == null) return;
    final map = <String, dynamic>{'cmd': command, ...payload};
    proc.stdin.writeln(jsonEncode(map));
    await proc.stdin.flush();
  }

  void _handleStdout(String line) {
    if (line.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map<String, dynamic>) return;
      _eventsCtrl.add(VoiceSidecarEvent.fromJson(decoded));
    } catch (_) {
      _eventsCtrl.add(
        VoiceSidecarEvent(
          type: VoiceSidecarEventType.status,
          rawType: 'log',
          message: line,
          meta: const {},
        ),
      );
    }
  }

  Future<_LaunchConfig> _resolveLaunch() async {
    final fromDefine = const String.fromEnvironment('VOICE_SIDECAR_BIN');
    if (fromDefine.trim().isNotEmpty) {
      return _LaunchConfig(exec: fromDefine.trim(), args: const []);
    }
    final fromEnv = dotenv.isInitialized ? dotenv.env['VOICE_SIDECAR_BIN'] : null;
    if (fromEnv != null && fromEnv.trim().isNotEmpty) {
      return _LaunchConfig(exec: fromEnv.trim(), args: const []);
    }

    final appDir = File(Platform.resolvedExecutable).parent.path;
    final exeName = Platform.isWindows ? 'voice_sidecar.exe' : 'voice_sidecar';
    final bundledExe = File('$appDir${Platform.pathSeparator}$exeName');
    if (await bundledExe.exists()) {
      return _LaunchConfig(exec: bundledExe.path, args: const [], cwd: appDir);
    }

    final bundledPy = File(
      '$appDir${Platform.pathSeparator}voice_sidecar${Platform.pathSeparator}main.py',
    );
    if (await bundledPy.exists()) {
      final py = await _resolvePython();
      return _LaunchConfig(exec: py, args: [bundledPy.path], cwd: appDir);
    }

    final devScript = File(
      '${Directory.current.path}${Platform.pathSeparator}native${Platform.pathSeparator}voice_sidecar${Platform.pathSeparator}main.py',
    );
    if (await devScript.exists()) {
      final py = await _resolvePython();
      return _LaunchConfig(
        exec: py,
        args: [devScript.path],
        cwd: Directory.current.path,
      );
    }

    throw StateError('No se encontró sidecar de voz (binario o script main.py).');
  }

  Future<String> _resolvePython() async {
    final fromDefine = _meaningfulPythonPath(
      const String.fromEnvironment('VOICE_SIDECAR_PYTHON'),
    );
    if (fromDefine != null) return fromDefine;
    final fromEnv = dotenv.isInitialized
        ? _meaningfulPythonPath(dotenv.env['VOICE_SIDECAR_PYTHON'])
        : null;
    if (fromEnv != null) return fromEnv;

    for (final start in <String>{
      Directory.current.path,
      File(Platform.resolvedExecutable).parent.path,
    }) {
      final venv = await _findSidecarVenvPython(start);
      if (venv != null) return venv;
    }

    if (Platform.isWindows) {
      return 'python';
    }
    return 'python3';
  }

  /// Sube directorios desde [startPath] buscando la venv creada por
  /// `native/voice_sidecar/scripts/bootstrap.ps1` (deps: sounddevice, vosk, etc.).
  static Future<String?> _findSidecarVenvPython(String startPath) async {
    final sep = Platform.pathSeparator;
    var dir = Directory(startPath);
    for (var i = 0; i < 18; i++) {
      if (Platform.isWindows) {
        final exe = File(
          '${dir.path}${sep}native${sep}voice_sidecar${sep}.venv${sep}Scripts${sep}python.exe',
        );
        if (await exe.exists()) return exe.path;
      } else {
        for (final name in ['python3', 'python']) {
          final bin = File(
            '${dir.path}${sep}native${sep}voice_sidecar${sep}.venv${sep}bin${sep}$name',
          );
          if (await bin.exists()) return bin.path;
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  /// `VOICE_SIDECAR_PYTHON=python` solo usa el intérprete del PATH (a menudo sin
  /// sounddevice). Si no es una ruta concreta, se ignora y se busca `.venv`.
  static String? _meaningfulPythonPath(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;
    final leaf = t.replaceAll(r'\', '/').split('/').last.toLowerCase();
    if (leaf == 'python' ||
        leaf == 'python3' ||
        leaf == 'python2' ||
        leaf == 'py') {
      return null;
    }
    return t;
  }
}

class _LaunchConfig {
  const _LaunchConfig({
    required this.exec,
    required this.args,
    this.cwd,
  });

  final String exec;
  final List<String> args;
  final String? cwd;
}

