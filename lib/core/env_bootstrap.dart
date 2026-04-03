import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';

/// Carga [dotenv] desde disco y, si no hay nada útil, desde el asset empaquetado
/// (Android/iOS no tienen `.env` junto al binario como en Windows).
///
/// Orden: cwd → junto al ejecutable (desktop) → documentos de la app → asset [`.env`]
/// (véase `pubspec.yaml`, sección `flutter.assets`). Las claves dentro del APK pueden
/// extraerse; para producción valora `--dart-define` o un backend propio.
Future<void> loadDotEnvFromDisk() async {
  String? content;
  for (final file in await _dotEnvCandidates()) {
    if (await file.exists()) {
      final s = await file.readAsString();
      if (s.trim().isNotEmpty) {
        content = s;
        break;
      }
    }
  }
  content ??= await _tryLoadBundledDotEnv();
  if (content != null && content.trim().isNotEmpty) {
    dotenv.loadFromString(envString: content);
  } else {
    dotenv.loadFromString(envString: '', isOptional: true);
  }
}

Future<String?> _tryLoadBundledDotEnv() async {
  try {
    final s = await rootBundle.loadString('.env');
    if (s.trim().isNotEmpty) return s;
  } catch (_) {}
  return null;
}

Future<List<File>> _dotEnvCandidates() async {
  final sep = Platform.pathSeparator;
  final list = <File>[
    File('${Directory.current.path}$sep.env'),
    File('${File(Platform.resolvedExecutable).parent.path}$sep.env'),
  ];
  try {
    final dir = await getApplicationDocumentsDirectory();
    list.add(File('${dir.path}$sep.env'));
  } catch (_) {}
  return list;
}
