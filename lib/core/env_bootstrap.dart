import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Carga [dotenv] desde un `.env` en disco (no hace falta listarlo en assets).
///
/// Orden: directorio de trabajo actual, luego carpeta del ejecutable (útil al distribuir el .exe).
Future<void> loadDotEnvFromDisk() async {
  String? content;
  for (final file in _dotEnvCandidates()) {
    if (await file.exists()) {
      content = await file.readAsString();
      break;
    }
  }
  if (content != null && content.trim().isNotEmpty) {
    dotenv.loadFromString(envString: content);
  } else {
    dotenv.loadFromString(envString: '', isOptional: true);
  }
}

Iterable<File> _dotEnvCandidates() sync* {
  yield File('${Directory.current.path}${Platform.pathSeparator}.env');
  yield File(
    '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}.env',
  );
}
