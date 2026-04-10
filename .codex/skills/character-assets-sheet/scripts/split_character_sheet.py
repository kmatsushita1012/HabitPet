#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image


@dataclass(frozen=True)
class Rect:
    x: int
    y: int
    w: int
    h: int

    @property
    def area(self) -> int:
        return self.w * self.h

    @property
    def right(self) -> int:
        return self.x + self.w

    @property
    def bottom(self) -> int:
        return self.y + self.h


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Split HabitPet character sheet into xcassets")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--character-id", required=True)
    parser.add_argument("--assets-root", required=True, type=Path)
    parser.add_argument("--min-pixels", type=int, default=80_000)
    parser.add_argument("--row-threshold", type=int, default=120)
    return parser.parse_args()


def connected_components(mask: np.ndarray) -> list[Rect]:
    h, w = mask.shape
    visited = np.zeros_like(mask, dtype=np.uint8)
    rects: list[Rect] = []

    for y in range(h):
        for x in range(w):
            if mask[y, x] == 0 or visited[y, x] == 1:
                continue

            stack = [(x, y)]
            visited[y, x] = 1
            min_x = max_x = x
            min_y = max_y = y
            pixels = 0

            while stack:
                cx, cy = stack.pop()
                pixels += 1
                min_x = min(min_x, cx)
                max_x = max(max_x, cx)
                min_y = min(min_y, cy)
                max_y = max(max_y, cy)

                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and mask[ny, nx] and not visited[ny, nx]:
                        visited[ny, nx] = 1
                        stack.append((nx, ny))

            rect = Rect(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
            if pixels > 0:
                rects.append(rect)

    return rects


def sort_reading_order(rects: list[Rect], row_threshold: int) -> list[Rect]:
    rows: list[list[Rect]] = []
    for rect in sorted(rects, key=lambda r: r.y):
        placed = False
        for row in rows:
            if abs(row[0].y - rect.y) <= row_threshold:
                row.append(rect)
                placed = True
                break
        if not placed:
            rows.append([rect])

    ordered: list[Rect] = []
    for row in rows:
        ordered.extend(sorted(row, key=lambda r: r.x))
    return ordered


def detect_cards(rgb: np.ndarray, min_pixels: int, row_threshold: int) -> list[Rect]:
    # Keep non-light pixels. Card borders/shadows remain connected while background is removed.
    gray = (
        0.299 * rgb[:, :, 0].astype(np.float32)
        + 0.587 * rgb[:, :, 1].astype(np.float32)
        + 0.114 * rgb[:, :, 2].astype(np.float32)
    )
    mask = (gray < 242).astype(np.uint8)
    rects = connected_components(mask)

    # Large components correspond to the 5 card regions.
    large = [r for r in rects if r.area >= min_pixels and r.w > 260 and r.h > 260]
    ordered = sort_reading_order(large, row_threshold=row_threshold)
    return ordered[:5]


def transparent_foreground(card_image: Image.Image) -> Image.Image:
    arr = np.array(card_image.convert("RGB")).astype(np.float32) / 255.0
    r = arr[:, :, 0]
    g = arr[:, :, 1]
    b = arr[:, :, 2]

    max_c = np.maximum(np.maximum(r, g), b)
    min_c = np.minimum(np.minimum(r, g), b)
    saturation = np.where(max_c == 0, 0.0, (max_c - min_c) / max_c)
    value = max_c

    keep = (saturation > 0.08) | (value < 0.9)

    rgba = np.zeros((arr.shape[0], arr.shape[1], 4), dtype=np.uint8)
    rgb_u8 = (arr * 255.0).astype(np.uint8)
    rgba[:, :, :3] = rgb_u8
    rgba[:, :, 3] = np.where(keep, 255, 0).astype(np.uint8)

    alpha = rgba[:, :, 3]
    ys, xs = np.where(alpha > 0)
    if len(xs) == 0 or len(ys) == 0:
        return Image.fromarray(rgba, mode="RGBA")

    min_x = int(xs.min())
    max_x = int(xs.max())
    min_y = int(ys.min())
    max_y = int(ys.max())

    trimmed = rgba[min_y : max_y + 1, min_x : max_x + 1]
    return Image.fromarray(trimmed)


def write_contents_json(imageset_dir: Path) -> None:
    data = {
        "images": [
            {"filename": "image.png", "idiom": "universal", "scale": "1x"},
            {"filename": "image@2x.png", "idiom": "universal", "scale": "2x"},
            {"filename": "image@3x.png", "idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (imageset_dir / "Contents.json").write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def save_scales(image_3x: Image.Image, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    w3, h3 = image_3x.size
    image_2x = image_3x.resize((max(1, round(w3 * 2 / 3)), max(1, round(h3 * 2 / 3))), Image.Resampling.LANCZOS)
    image_1x = image_3x.resize((max(1, round(w3 / 3)), max(1, round(h3 / 3))), Image.Resampling.LANCZOS)

    image_1x.save(output_dir / "image.png")
    image_2x.save(output_dir / "image@2x.png")
    image_3x.save(output_dir / "image@3x.png")
    write_contents_json(output_dir)


def main() -> int:
    args = parse_args()

    if not args.input.exists():
        raise FileNotFoundError(f"input not found: {args.input}")

    source = Image.open(args.input).convert("RGB")
    source_np = np.array(source)

    cards = detect_cards(source_np, min_pixels=args.min_pixels, row_threshold=args.row_threshold)
    if len(cards) != 5:
        raise RuntimeError(f"expected 5 cards, detected {len(cards)}")

    character_dir = args.assets_root / f"character_{args.character_id}"
    character_dir.mkdir(parents=True, exist_ok=True)

    for idx, rect in enumerate(cards, start=1):
        # Inner crop to remove rectangular frame and bottom label area.
        margin_x = int(rect.w * 0.06)
        top_margin = int(rect.h * 0.08)
        bottom_cut = int(rect.h * 0.19)

        left = rect.x + margin_x
        right = rect.right - margin_x
        top = rect.y + top_margin
        bottom = rect.bottom - bottom_cut

        card_crop = source.crop((left, top, right, bottom))
        fg = transparent_foreground(card_crop)

        imageset_name = f"character_{args.character_id}_lv{idx}.imageset"
        imageset_dir = character_dir / imageset_name
        save_scales(fg, imageset_dir)
        print(f"generated: {imageset_dir}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
