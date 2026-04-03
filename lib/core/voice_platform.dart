import 'package:flutter/foundation.dart';

/// El sidecar de wake word (proceso Python/binario junto al cliente) solo corre en
/// escritorio. En Android/iOS/web se usa modo manual o texto.
bool get voiceSidecarSupported {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;
}
