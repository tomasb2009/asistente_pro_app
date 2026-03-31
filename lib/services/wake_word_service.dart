/// El wake word real está integrado en el sidecar nativo open-source.
/// Este contrato se mantiene para compatibilidad futura.
abstract class WakeWordService {
  Future<void> start(void Function() onWake);
  Future<void> stop();
}

class StubWakeWordService implements WakeWordService {
  @override
  Future<void> start(void Function() onWake) async {}

  @override
  Future<void> stop() async {}
}

