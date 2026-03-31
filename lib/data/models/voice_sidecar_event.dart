enum VoiceSidecarEventType {
  ready,
  wakeDetected,
  speechStart,
  recordingStarted,
  recordingStopped,
  commandReady,
  status,
  error,
}

VoiceSidecarEventType _parseType(String raw) {
  switch (raw) {
    case 'ready':
      return VoiceSidecarEventType.ready;
    case 'wake_detected':
      return VoiceSidecarEventType.wakeDetected;
    case 'speech_start':
      return VoiceSidecarEventType.speechStart;
    case 'recording_started':
      return VoiceSidecarEventType.recordingStarted;
    case 'recording_stopped':
      return VoiceSidecarEventType.recordingStopped;
    case 'command_ready':
      return VoiceSidecarEventType.commandReady;
    case 'status':
      return VoiceSidecarEventType.status;
    case 'error':
      return VoiceSidecarEventType.error;
    default:
      return VoiceSidecarEventType.status;
  }
}

class VoiceSidecarEvent {
  const VoiceSidecarEvent({
    required this.type,
    required this.rawType,
    this.wavPath,
    this.message,
    this.durationMs,
    this.meta = const <String, dynamic>{},
  });

  final VoiceSidecarEventType type;
  final String rawType;
  final String? wavPath;
  final String? message;
  final int? durationMs;
  final Map<String, dynamic> meta;

  factory VoiceSidecarEvent.fromJson(Map<String, dynamic> json) {
    final raw = (json['event'] ?? json['type'] ?? 'status').toString();
    return VoiceSidecarEvent(
      type: _parseType(raw),
      rawType: raw,
      wavPath: json['wav_path'] as String?,
      message: json['message'] as String?,
      durationMs: (json['duration_ms'] as num?)?.round(),
      meta: json,
    );
  }
}

