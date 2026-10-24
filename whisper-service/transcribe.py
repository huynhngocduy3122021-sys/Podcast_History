
from faster_whisper import WhisperModel
from pathlib import Path
import sys

if len(sys.argv) < 2:
    print('Usage: python transcribe.py "path-to-audio-or-video"')
    sys.exit(1)

media_path = Path(sys.argv[1])

if not media_path.is_file():
    print(f"File not found: {media_path}")
    sys.exit(1)

print("Loading Whisper model...")

model = WhisperModel(
    "small",
    device="cpu",
    compute_type="int8"
)

print("Transcribing media...")

segments, info = model.transcribe(
    str(media_path),
    language="vi",
    beam_size=3,
    vad_filter=True
)

output_path = media_path.with_suffix(".txt")

with output_path.open("w", encoding="utf-8") as output:
    for segment in segments:
        line = segment.text.strip()
        if line:
            output.write(line + "\n")
            print(line)

print(f"Done! Output saved to: {output_path}")
