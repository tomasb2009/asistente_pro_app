#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_EXE="${PYTHON_EXE:-python3}"
MODEL_URL="${MODEL_URL:-https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip}"

"$PYTHON_EXE" -m venv "$ROOT_DIR/.venv"
"$ROOT_DIR/.venv/bin/python" -m pip install --upgrade pip
"$ROOT_DIR/.venv/bin/python" -m pip install -r "$ROOT_DIR/requirements.txt"
if ! "$ROOT_DIR/.venv/bin/python" -m pip install -r "$ROOT_DIR/requirements-optional.txt"; then
  echo "WARN: no se pudo instalar RNNoise opcional; se continúa sin denoise."
fi

mkdir -p "$ROOT_DIR/models"
ZIP_PATH="$ROOT_DIR/models/vosk-model-small-es-0.42.zip"
curl -L "$MODEL_URL" -o "$ZIP_PATH"
unzip -o "$ZIP_PATH" -d "$ROOT_DIR/models"

echo "Sidecar listo en $ROOT_DIR"

