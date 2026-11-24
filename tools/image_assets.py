"""Load raster and SVG artwork into detached Pillow RGBA images for QA previews."""
from __future__ import annotations

from io import BytesIO
from pathlib import Path

import cairosvg
from PIL import Image


def open_image(path: Path | str) -> Image.Image:
    """Decode an image file, rasterizing SVG at its authored pixel dimensions."""
    source = Path(path)
    if source.suffix.lower() == ".svg":
        payload = cairosvg.svg2png(url=str(source))
        with Image.open(BytesIO(payload)) as opened:
            opened.load()
            return opened.convert("RGBA")

    with Image.open(source) as opened:
        opened.load()
        return opened.convert("RGBA")
