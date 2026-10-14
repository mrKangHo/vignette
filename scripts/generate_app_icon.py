#!/usr/bin/env python3
"""Regenerates Resources/Vignette/Assets.xcassets/AppIcon.appiconset.

Depicts Vignette's core idea directly: two displays on a dark, vignetted
field, one dimmed and one glowing warm -- the "active" screen during Movie
Mode. Requires numpy + Pillow (`pip install numpy pillow`).
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 2048  # master render resolution; final sizes are downsampled from this

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(
    REPO_ROOT, "Resources/Vignette/Assets.xcassets/AppIcon.appiconset"
)


def squircle_mask(size, n=5.0):
    a = size / 2.0
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64)
    xs = xs - a + 0.5
    ys = ys - a + 0.5
    val = (np.abs(xs) / a) ** n + (np.abs(ys) / a) ** n
    # narrow antialias band (~2px at master res) centered on the val==1 boundary
    lo, hi = 1.0 - 0.0035, 1.0 + 0.0035
    t = np.clip((val - lo) / (hi - lo), 0, 1)
    mask = 255.0 * (1.0 - t)
    return Image.fromarray(mask.astype(np.uint8), mode="L")


def vertical_gradient_rgb(size, top_color, bottom_color):
    top = np.array(top_color, dtype=np.float32)
    bottom = np.array(bottom_color, dtype=np.float32)
    t = np.linspace(0, 1, size, dtype=np.float32).reshape(size, 1, 1)
    row = top * (1 - t) + bottom * t  # (size,1,3)
    grad = np.repeat(row, size, axis=1)
    return grad  # float32 (size,size,3)


def radial_vignette(size, strength=0.62, falloff=1.7):
    c = size / 2.0
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64)
    d = np.sqrt((xs - c) ** 2 + (ys - c) ** 2) / (size / 2.0 * math.sqrt(2))
    d = np.clip(d, 0, 1)
    return 1 - strength * (d ** falloff)


def rounded_rect_layer(size, box, radius, fill_rgb_top, fill_rgb_bottom=None):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)

    if fill_rgb_bottom is None:
        rgb = Image.new("RGB", (size, size), fill_rgb_top)
    else:
        x0, y0, x1, y1 = box
        h = max(1, int(y1 - y0))
        grad = vertical_gradient_rgb(h, fill_rgb_top, fill_rgb_bottom).astype(np.uint8)
        row_img = Image.fromarray(grad[:, 0:1, :].repeat(size, axis=1))
        rgb = Image.new("RGB", (size, size), fill_rgb_top)
        rgb.paste(row_img, (0, int(y0)))

    img.paste(rgb, (0, 0))
    img.putalpha(mask)
    return img


def blurred_glow(size, box, radius, color_rgba, blur_px, expand=0):
    x0, y0, x1, y1 = box
    box2 = (x0 - expand, y0 - expand, x1 + expand, y1 + expand)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle(box2, radius=radius + expand, fill=color_rgba)
    return img.filter(ImageFilter.GaussianBlur(blur_px))


def main():
    bg_grad = vertical_gradient_rgb(S, (30, 33, 44), (7, 8, 11))
    vign = radial_vignette(S, strength=0.60, falloff=1.65)
    bg_rgb = np.clip(bg_grad * vign[..., None], 0, 255).astype(np.uint8)
    bg = Image.fromarray(bg_rgb, "RGB").convert("RGBA")
    squircle = squircle_mask(S, n=5.0)
    bg.putalpha(squircle)

    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    canvas.alpha_composite(bg)

    # back monitor: dim / inactive display
    back_box = (S * 0.145, S * 0.145, S * 0.630, S * 0.560)
    back = rounded_rect_layer(
        S, back_box, S * 0.050,
        fill_rgb_top=(76, 80, 95), fill_rgb_bottom=(58, 61, 74),
    )
    canvas.alpha_composite(back)

    # front monitor: the active, glowing display
    front_box = (S * 0.330, S * 0.395, S * 0.860, S * 0.845)
    front_radius = S * 0.055

    shadow = blurred_glow(
        S, front_box, front_radius,
        color_rgba=(0, 0, 0, 150), blur_px=S * 0.018, expand=S * 0.004,
    )
    canvas.alpha_composite(shadow)

    glow = blurred_glow(
        S, front_box, front_radius,
        color_rgba=(255, 178, 90, 210), blur_px=S * 0.045, expand=S * 0.008,
    )
    canvas.alpha_composite(glow)

    glow2 = blurred_glow(
        S, front_box, front_radius,
        color_rgba=(255, 205, 140, 255), blur_px=S * 0.020, expand=0,
    )
    canvas.alpha_composite(glow2)

    front = rounded_rect_layer(
        S, front_box, front_radius,
        fill_rgb_top=(255, 248, 235), fill_rgb_bottom=(255, 179, 89),
    )
    canvas.alpha_composite(front)

    # re-mask in case blur bled past the squircle's safe area
    a_arr = np.array(canvas.split()[3], dtype=np.uint16)
    squircle_arr = np.array(squircle, dtype=np.uint16)
    canvas.putalpha(Image.fromarray((a_arr * squircle_arr // 255).astype(np.uint8), "L"))

    os.makedirs(OUT_DIR, exist_ok=True)
    sizes = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    for name, px in sizes.items():
        canvas.resize((px, px), Image.LANCZOS).save(os.path.join(OUT_DIR, name))

    print(f"wrote {len(sizes)} icon sizes to {OUT_DIR}")


if __name__ == "__main__":
    main()
