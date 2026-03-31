param(
  [string]$PythonExe = "python",
  [string]$ModelUrl = "https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$venv = Join-Path $root ".venv"
$modelDir = Join-Path $root "models"

& $PythonExe -m venv $venv
& (Join-Path $venv "Scripts\\python.exe") -m pip install --upgrade pip
& (Join-Path $venv "Scripts\\python.exe") -m pip install -r (Join-Path $root "requirements.txt")
try {
  & (Join-Path $venv "Scripts\\python.exe") -m pip install -r (Join-Path $root "requirements-optional.txt")
} catch {
  Write-Warning "No se pudo instalar requirements-optional.txt (RNNoise). Se continúa sin denoise."
}

New-Item -ItemType Directory -Force -Path $modelDir | Out-Null
$zipPath = Join-Path $modelDir "vosk-model-small-es-0.42.zip"
Invoke-WebRequest -Uri $ModelUrl -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $modelDir -Force

Write-Host "Sidecar listo. Modelo y entorno instalados en: $root"

