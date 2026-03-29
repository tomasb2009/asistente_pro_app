/// La wake phrase («ok asistente») usa ventanas de audio con Whisper; ver
/// `lib/services/jarvis_wake_session.dart`.
abstract class WakeWordService {
  Future<void> start(void Function() onWake);
  Future<void> stop();
}

/// Reservado; la pantalla Hablar usa la sesión Jarvis integrada.
class StubWakeWordService implements WakeWordService {
  @override
  Future<void> start(void Function() onWake) async {}

  @override
  Future<void> stop() async {}
}
