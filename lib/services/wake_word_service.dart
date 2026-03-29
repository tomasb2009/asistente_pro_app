/// Fase 1: sin wake word nativo. Fase 2: integrar Porcupine/FFI según plataforma.
///
/// La detección continua de “Asistente” en segundo plano en escritorio no es trivial;
/// usar botón “Escuchar” o atajo global es la vía pragmática hasta integrar un motor dedicado.
abstract class WakeWordService {
  Future<void> start(void Function() onWake);
  Future<void> stop();
}

/// Implementación vacía: el usuario activa la escucha con el botón de la UI.
class StubWakeWordService implements WakeWordService {
  @override
  Future<void> start(void Function() onWake) async {}

  @override
  Future<void> stop() async {}
}
