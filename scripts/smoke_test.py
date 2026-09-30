"""Exercise one local Seed-VC V1 conversion through the Gradio API."""

from pathlib import Path

from gradio_client import Client, handle_file

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / "seed-vc/examples/source/yae_0.wav"
reference = ROOT / "seed-vc/examples/reference/dingzhen_0.wav"

client = Client("http://127.0.0.1:7860/")
result = client.predict(
    handle_file(str(source)),
    handle_file(str(reference)),
    4,
    1.0,
    0.7,
    False,
    True,
    0,
    api_name="/predict",
)
full_audio = Path(result[1])
assert full_audio.is_file() and full_audio.stat().st_size > 1000, result
print(f"Converted audio: {full_audio} ({full_audio.stat().st_size} bytes)")
