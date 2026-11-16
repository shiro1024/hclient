#!/usr/bin/env python3
"""Render the approved SVG into launcher master and transparent foreground PNGs.

Requires ImageMagick (`magick`) and Python 3. From the repository root:
  python3 tool/generate_app_icons.py
  dart run flutter_launcher_icons
"""

import argparse
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET


def render(source: Path, output: Path, size: int) -> None:
    # Render the vector at four times the target resolution before downsampling.
    subprocess.run(
        [
            "magick", "-background", "none", "-density", "384", str(source),
            "-colorspace", "sRGB", "-filter", "Lanczos",
            "-resize", f"{size}x{size}", "-depth", "8", "-strip",
            f"PNG32:{output}",
        ],
        check=True,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source", type=Path,
        default=Path(__file__).resolve().parents[1] / "assets/icon/hclient.svg",
    )
    parser.add_argument("--size", type=int, default=1024)
    args = parser.parse_args()
    source = args.source.resolve()
    render(source, source.with_suffix(".png"), args.size)
    tree = ET.parse(source)
    root = tree.getroot()
    background = next(child for child in root if child.get("id") == "background")
    root.remove(background)
    ET.register_namespace("", "http://www.w3.org/2000/svg")
    with tempfile.TemporaryDirectory(prefix="hclient-icon-") as directory:
        foreground = Path(directory) / "foreground.svg"
        tree.write(foreground, encoding="utf-8", xml_declaration=True)
        render(
            foreground,
            source.with_name(f"{source.stem}-foreground.png"),
            args.size,
        )


if __name__ == "__main__":
    main()
