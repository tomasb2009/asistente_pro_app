/// Zonas de luces: alinea los textos con los comandos que entiende tu backend/MQTT.
class LightZoneConfig {
  const LightZoneConfig({
    required this.id,
    required this.label,
    required this.onMessage,
    required this.offMessage,
  });

  final String id;
  final String label;
  final String onMessage;
  final String offMessage;
}

/// Lista editable: debe coincidir con `MQTT_HOME_ZONES` u ordenes equivalentes en el backend.
const List<LightZoneConfig> lightZoneConfigs = [
  LightZoneConfig(
    id: 'living',
    label: 'Salón',
    onMessage: 'enciende la luz del salón',
    offMessage: 'apaga la luz del salón',
  ),
  LightZoneConfig(
    id: 'comedor',
    label: 'Comedor',
    onMessage: 'enciende la luz del comedor',
    offMessage: 'apaga la luz del comedor',
  ),
  LightZoneConfig(
    id: 'patio',
    label: 'Patio',
    onMessage: 'enciende la luz del patio',
    offMessage: 'apaga la luz del patio',
  ),
];

const String allLightsOnMessage = 'enciende todas las luces';
const String allLightsOffMessage = 'apaga todas las luces';
