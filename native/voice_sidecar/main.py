#!/usr/bin/env python3
import collections
import json
import os
import queue
import sys
import tempfile
import threading
import time
import unicodedata
import wave
from pathlib import Path

import numpy as np
import sounddevice as sd
import webrtcvad
from vosk import KaldiRecognizer, Model

try:
    from rnnoise_wrapper import RNNoise
except Exception:
    RNNoise = None


def emit(event, **kwargs):
    payload = {"event": event, **kwargs}
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def norm_text(text: str) -> str:
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    return " ".join(text.lower().replace(",", " ").split())


def wake_variants(wake_phrase: str):
    base = norm_text(wake_phrase)
    variants = {base}
    # Fallbacks comunes para el caso por defecto en es-AR/es-ES.
    if base == "ok asistente":
        variants.update(
            {
                "ok asistente",
                "oke asistente",
                "okey asistente",
                "okay asistente",
                "oye asistente",
            }
        )
    return variants


def text_has_wake(text: str, wake_set) -> bool:
    txt = norm_text(text)
    if not txt:
        return False
    return any(w in txt for w in wake_set)


def write_wav(path, samples, sample_rate=16000):
    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(samples.tobytes())


class Sidecar:
    def __init__(self):
        self.running = False
        self.paused = False
        self.stream = None
        self.audio_q = queue.Queue(maxsize=600)
        self.cmd_q = queue.Queue()
        self.worker = None
        self.cfg = {
            "wake_phrase": "ok asistente",
            "sample_rate_hz": 16000,
            "frame_ms": 30,
            "command_silence_ms": 1400,
            "max_command_ms": 45000,
            "pre_roll_ms": 350,
            "post_roll_ms": 180,
            "enable_rnnoise": True,
            "enable_webrtc_vad": True,
        }
        self.vad = webrtcvad.Vad(2)
        self.rn = RNNoise() if RNNoise is not None else None
        self._load_config_file()
        self.model = self._load_vosk_model()
        self.rec = KaldiRecognizer(self.model, self.cfg["sample_rate_hz"])
        self.rec.SetWords(False)

    def _load_config_file(self):
        cfg_path = Path(__file__).parent / "config" / "default.json"
        if cfg_path.exists():
            try:
                self.cfg.update(json.loads(cfg_path.read_text(encoding="utf-8")))
            except Exception as e:
                emit("error", message=f"config parse error: {e}")

    def _load_vosk_model(self):
        model_dir = os.environ.get("VOICE_SIDECAR_VOSK_MODEL")
        if model_dir and Path(model_dir).exists():
            return Model(model_dir)
        local = Path(__file__).parent / "models" / "vosk-model-small-es-0.42"
        if local.exists():
            return Model(str(local))
        raise RuntimeError(
            "No se encontró modelo Vosk. Define VOICE_SIDECAR_VOSK_MODEL o instala models/vosk-model-small-es-0.42"
        )

    def _audio_callback(self, indata, frames, t, status):
        if status:
            emit("status", message=f"audio status: {status}")
        if self.paused:
            return
        chunk = bytes(indata)
        try:
            self.audio_q.put_nowait(chunk)
        except queue.Full:
            # Drop oldest then push newest to keep realtime
            try:
                self.audio_q.get_nowait()
            except queue.Empty:
                pass
            try:
                self.audio_q.put_nowait(chunk)
            except Exception:
                pass

    def _start_audio(self):
        sr = int(self.cfg["sample_rate_hz"])
        frame_ms = int(self.cfg["frame_ms"])
        frame_samples = int(sr * frame_ms / 1000)
        self.stream = sd.RawInputStream(
            samplerate=sr,
            channels=1,
            dtype="int16",
            blocksize=frame_samples,
            callback=self._audio_callback,
        )
        self.stream.start()

    def _stop_audio(self):
        if self.stream is None:
            return
        try:
            self.stream.stop()
            self.stream.close()
        except Exception:
            pass
        self.stream = None

    def start(self, cfg_update):
        self.cfg.update(cfg_update or {})
        self.paused = False
        if self.running:
            return
        self.running = True
        self._start_audio()
        self.worker = threading.Thread(target=self._worker_loop, daemon=True)
        self.worker.start()
        emit("ready", wake_phrase=self.cfg["wake_phrase"])

    def stop(self):
        self.running = False
        self.paused = False
        self._stop_audio()
        emit("status", message="stopped")

    def pause(self):
        self.paused = True
        emit("status", message="paused")

    def resume(self):
        self.paused = False
        emit("status", message="resumed")

    def _denoise(self, pcm16):
        if not self.cfg.get("enable_rnnoise", True) or self.rn is None:
            return pcm16
        try:
            # rnnoise_wrapper works with float32 [-1,1]
            f = pcm16.astype(np.float32) / 32768.0
            out = self.rn.process_frame(f)
            if out is None:
                return pcm16
            out = np.clip(out * 32768.0, -32768, 32767).astype(np.int16)
            return out
        except Exception:
            return pcm16

    def _worker_loop(self):
        sr = int(self.cfg["sample_rate_hz"])
        frame_ms = int(self.cfg["frame_ms"])
        wake_set = wake_variants(self.cfg["wake_phrase"])
        silence_ms = int(self.cfg["command_silence_ms"])
        max_ms = int(self.cfg["max_command_ms"])
        pre_roll_ms = int(self.cfg["pre_roll_ms"])
        post_roll_ms = int(self.cfg["post_roll_ms"])

        frame_samples = int(sr * frame_ms / 1000)
        pre_roll_frames = max(1, pre_roll_ms // frame_ms)
        post_roll_frames = max(0, post_roll_ms // frame_ms)

        ring = collections.deque(maxlen=pre_roll_frames)
        mode = "scan"
        command_frames = []
        silence_acc_ms = 0
        command_elapsed_ms = 0
        post_roll_left = 0
        rec_started_emitted = False

        while self.running:
            try:
                chunk = self.audio_q.get(timeout=0.5)
            except queue.Empty:
                continue
            if self.paused:
                continue

            pcm = np.frombuffer(chunk, dtype=np.int16)
            if len(pcm) != frame_samples:
                continue

            pcm = self._denoise(pcm)
            chunk = pcm.tobytes()
            ring.append(chunk)

            is_speech = True
            if self.cfg.get("enable_webrtc_vad", True):
                try:
                    is_speech = self.vad.is_speech(chunk, sr)
                except Exception:
                    is_speech = True

            if mode == "scan":
                try:
                    accepted = self.rec.AcceptWaveform(chunk)
                    part = json.loads(self.rec.PartialResult()).get("partial", "")
                    full = json.loads(self.rec.Result()).get("text", "") if accepted else ""
                except Exception:
                    part = ""
                    full = ""

                candidate = full or part
                if candidate and text_has_wake(candidate, wake_set):
                    emit("wake_detected", text=candidate)
                    mode = "record"
                    command_frames = list(ring)
                    silence_acc_ms = 0
                    command_elapsed_ms = len(command_frames) * frame_ms
                    post_roll_left = post_roll_frames
                    if not rec_started_emitted:
                        emit("recording_started")
                        rec_started_emitted = True
                    continue

            elif mode == "record":
                command_frames.append(chunk)
                command_elapsed_ms += frame_ms
                if is_speech:
                    silence_acc_ms = 0
                    post_roll_left = post_roll_frames
                else:
                    silence_acc_ms += frame_ms
                    if post_roll_left > 0:
                        post_roll_left -= 1

                should_stop = False
                if command_elapsed_ms >= max_ms:
                    should_stop = True
                elif silence_acc_ms >= silence_ms and post_roll_left <= 0:
                    should_stop = True

                if should_stop:
                    arr = np.frombuffer(b"".join(command_frames), dtype=np.int16)
                    out_path = (
                        Path(tempfile.gettempdir())
                        / f"sidecar_cmd_{int(time.time() * 1000)}.wav"
                    )
                    try:
                        write_wav(str(out_path), arr, sr)
                        emit("recording_stopped", duration_ms=command_elapsed_ms)
                        emit(
                            "command_ready",
                            wav_path=str(out_path),
                            duration_ms=command_elapsed_ms,
                        )
                    except Exception as e:
                        emit("error", message=f"wav write error: {e}")

                    # reset scanning
                    self.rec = KaldiRecognizer(self.model, sr)
                    self.rec.SetWords(False)
                    mode = "scan"
                    command_frames = []
                    rec_started_emitted = False
                    silence_acc_ms = 0
                    command_elapsed_ms = 0
                    post_roll_left = 0


def stdin_loop(sc: Sidecar):
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            cmd = json.loads(line)
        except Exception:
            emit("error", message=f"json command inválido: {line}")
            continue

        name = cmd.get("cmd")
        if name == "start":
            sc.start({k: v for k, v in cmd.items() if k != "cmd"})
        elif name == "pause":
            sc.pause()
        elif name == "resume":
            sc.resume()
        elif name == "stop":
            sc.stop()
            break
        else:
            emit("error", message=f"cmd desconocido: {name}")


def main():
    try:
        sc = Sidecar()
    except Exception as e:
        emit("error", message=str(e))
        return 2

    try:
        stdin_loop(sc)
    finally:
        sc.stop()
    return 0


if __name__ == "__main__":
    sys.exit(main())

