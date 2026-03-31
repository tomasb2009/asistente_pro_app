# Voice Sidecar (Desktop OSS)

Sidecar nativo ejecutado como proceso externo por Flutter.

Pipeline:

- Captura de micrófono en PCM 16 kHz mono
- RNNoise (opcional)
- WebRTC VAD (opcional)
- Detección de wake phrase (`ok asistente`) usando Vosk
- Segmentación de comando por silencio + timeout
- Emisión de WAV final para transcribir con Whisper en Flutter

## Instalación (dev)

```bash
python -m venv .venv
.venv/Scripts/activate   # Windows
pip install -r native/voice_sidecar/requirements.txt
```

o usar scripts:

- Windows: `native/voice_sidecar/scripts/bootstrap.ps1`
- Linux/macOS: `native/voice_sidecar/scripts/bootstrap.sh`

## Variables útiles

- `VOICE_SIDECAR_PYTHON`: ejecutable Python a usar
- `VOICE_SIDECAR_BIN`: ruta a binario sidecar compilado (si existe)
- `VOICE_SIDECAR_VOSK_MODEL`: carpeta del modelo Vosk si no se usa `native/voice_sidecar/models/*`
- `VOICE_WAKE_PHRASE`: frase de activación (default: `ok asistente`)
- `VOICE_COMMAND_SILENCE_MS`: corte por silencio (default: 1400)
- `VOICE_MAX_COMMAND_MS`: timeout máximo (default: 45000)

Nota RNNoise:

- `rnnoise-wrapper` es opcional.
- Si tu Python/plataforma no tiene wheel compatible, el bootstrap continúa sin denoise.
- El sidecar sigue funcionando con WebRTC VAD + wake phrase.

## IPC JSONL

Comandos por `stdin`:

- `{"cmd":"start", ...config}`
- `{"cmd":"pause"}`
- `{"cmd":"resume"}`
- `{"cmd":"stop"}`

Eventos por `stdout`:

- `ready`
- `wake_detected`
- `recording_started`
- `recording_stopped`
- `command_ready` con `wav_path`
- `error`
- `status`

