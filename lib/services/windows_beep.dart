import 'dart:ffi' as ffi;
import 'dart:io';

/// Pitido del sistema vía `kernel32.Beep` (funciona aunque el mic esté grabando).
void windowsBeep(int frequencyHz, int durationMs) {
  if (!Platform.isWindows) return;
  final freq = frequencyHz.clamp(37, 32767);
  final ms = durationMs.clamp(1, 0x7fffffff);
  try {
    final lib = ffi.DynamicLibrary.open('kernel32.dll');
    final beep = lib.lookupFunction<
        ffi.Int32 Function(ffi.Uint32, ffi.Uint32),
        int Function(int, int)>('Beep');
    beep(freq, ms);
  } catch (_) {}
}
