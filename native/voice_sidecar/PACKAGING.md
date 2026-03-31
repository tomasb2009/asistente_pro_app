# Packaging desktop (Windows/Linux/macOS)

## Windows

- `windows/CMakeLists.txt` copia `native/voice_sidecar/` junto al `.exe` como `voice_sidecar/`.
- El cliente Dart busca:
  1. `VOICE_SIDECAR_BIN`
  2. `VOICE_SIDECAR_PYTHON + voice_sidecar/main.py`
  3. `native/voice_sidecar/main.py` en desarrollo

## Linux

- `linux/CMakeLists.txt` instala `native/voice_sidecar/` en `${bundle}/voice_sidecar`.
- El ejecutable principal resuelve `voice_sidecar/main.py` relativo al binario.

## macOS

- Este repo no tiene todavía target `macos/Runner` generado.
- Al generar `macos`:
  - copiar `native/voice_sidecar/` dentro del `.app/Contents/MacOS/voice_sidecar/`,
  - asegurar Python embebido o sidecar compilado,
  - setear `VOICE_SIDECAR_BIN` en release para evitar dependencia externa de Python.

