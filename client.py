import json
import os
import queue
import sys
import threading
import time
import traceback

import keyboard
import numpy as np
import requests
import sounddevice as sd
import soundfile as sf

CONFIG_PATH = "config.json"


def load_config(path):
    if not os.path.exists(path):
        raise FileNotFoundError(f"Config file not found: {path}")
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def build_url(config):
    host = config.get("iphone_ip")
    port = config.get("port", 8080)
    return f"http://{host}:{port}/transcribe"


class AudioRecorder:
    def __init__(self, samplerate, channels, max_duration_seconds):
        self.samplerate = samplerate
        self.channels = channels
        self.max_duration_seconds = max_duration_seconds
        self.frames = []
        self.stream = None
        self.event = threading.Event()

    def callback(self, indata, frames, time_info, status):
        if status:
            print("[Recorder] Warning:", status, file=sys.stderr)
        self.frames.append(indata.copy())
        if (len(self.frames) * indata.shape[0]) / self.samplerate >= self.max_duration_seconds:
            self.event.set()

    def start(self):
        self.frames = []
        self.event.clear()
        self.stream = sd.InputStream(
            samplerate=self.samplerate,
            channels=self.channels,
            callback=self.callback,
            dtype="float32",
        )
        self.stream.start()

    def stop(self):
        if self.stream is not None:
            self.stream.stop()
            self.stream.close()
            self.stream = None
        self.event.set()

    def save_wav(self, path):
        if not self.frames:
            raise ValueError("No audio recorded")
        audio = np.concatenate(self.frames, axis=0)
        sf.write(path, audio, self.samplerate)


def record_audio(config):
    samplerate = int(config.get("sample_rate", 44100))
    channels = int(config.get("channels", 1))
    max_duration = float(config.get("max_duration_seconds", 20))
    recorder = AudioRecorder(samplerate, channels, max_duration)
    recorder.start()
    print("Recording... release the hotkey to send audio.")
    while keyboard.is_pressed(config.get("hotkey", "right ctrl")):
        if recorder.event.wait(0.1):
            break
    recorder.stop()
    return recorder


def send_audio(url, wav_path, timeout):
    with open(wav_path, "rb") as f:
        response = requests.post(url, data=f, timeout=timeout)
    response.raise_for_status()
    return response.json()


def type_text(text):
    if not text:
        return
    print("Typing text:", text)
    keyboard.write(text, delay=0.01)


def run_client():
    try:
        config = load_config(CONFIG_PATH)
    except Exception as exc:
        print(f"Error loading config: {exc}")
        sys.exit(1)

    hotkey = config.get("hotkey", "right ctrl")
    url = build_url(config)
    timeout = float(config.get("request_timeout_seconds", 15))

    print("WhisperServer client started")
    print(f"Hotkey: hold {hotkey} to record, release to submit")
    print(f"Target URL: {url}")
    print("Press Ctrl+C to quit.")

    while True:
        try:
            keyboard.wait(hotkey)
            if not keyboard.is_pressed(hotkey):
                continue
            recorder = record_audio(config)
            temp_wav = os.path.join(os.getcwd(), "temp_transcribe.wav")
            try:
                recorder.save_wav(temp_wav)
            except Exception as exc:
                print("Error saving WAV:", exc)
                continue

            try:
                result = send_audio(url, temp_wav, timeout)
                text = result.get("text", "") if isinstance(result, dict) else ""
                if not text:
                    print("No transcription returned.")
                else:
                    type_text(text)
            except Exception as exc:
                print("Error sending audio or transcribing:")
                traceback.print_exc()
            finally:
                try:
                    os.remove(temp_wav)
                except OSError:
                    pass
        except KeyboardInterrupt:
            print("Client stopped.")
            break
        except Exception as exc:
            print("Unexpected error:", exc)
            traceback.print_exc()
            time.sleep(1)


if __name__ == "__main__":
    run_client()
