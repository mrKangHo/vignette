#!/usr/bin/env python3
"""Regenerates the MenuBarIconOff/MenuBarIconOn template imagesets.

Two overlapping rounded rects (same composition as the app icon, minus
color): the back one's alpha is baked in per-variant so Movie Mode's
"on" state reads dimmer, since MenuBarExtra's custom-label path needs an
actual template Image asset here -- live SwiftUI Shape/Color content
doesn't reliably render through it (see MenuBarIconView.swift).
Requires Pillow (`pip install pillow`).
"""
import os

from PIL import Image, ImageDraw

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO_ROOT, "Resources/Vignette/Assets.xcassets")


def draw(scale, back_alpha):
    w, h = int(18 * scale), int(16 * scale)
    supersample = 4
    img = Image.new("RGBA", (w * supersample, h * supersample), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def rect(cx, cy, rw, rh, radius, alpha):
        x0 = (w / 2 + cx - rw / 2) * supersample
        y0 = (h / 2 + cy - rh / 2) * supersample
        x1 = (w / 2 + cx + rw / 2) * supersample
        y1 = (h / 2 + cy + rh / 2) * supersample
        d.rounded_rectangle([x0, y0, x1, y1], radius=radius * scale * supersample, fill=(0, 0, 0, alpha))

    rect(-3, -2.75, 11, 8, 2.2, back_alpha)  # back display
    rect(3, 2.75, 11, 8, 2.2, 255)  # front display, always opaque

    return img.resize((w, h), Image.LANCZOS)


def write_imageset(name, back_alpha):
    dirpath = os.path.join(OUT, f"{name}.imageset")
    os.makedirs(dirpath, exist_ok=True)
    for scale, suffix in [(1, ""), (2, "@2x"), (3, "@3x")]:
        draw(scale, back_alpha).save(os.path.join(dirpath, f"{name}{suffix}.png"))

    contents = f"""{{
  "images" : [
    {{
      "filename" : "{name}.png",
      "idiom" : "universal",
      "scale" : "1x"
    }},
    {{
      "filename" : "{name}@2x.png",
      "idiom" : "universal",
      "scale" : "2x"
    }},
    {{
      "filename" : "{name}@3x.png",
      "idiom" : "universal",
      "scale" : "3x"
    }}
  ],
  "info" : {{
    "author" : "xcode",
    "version" : 1
  }},
  "properties" : {{
    "template-rendering-intent" : "template"
  }}
}}
"""
    with open(os.path.join(dirpath, "Contents.json"), "w") as f:
        f.write(contents)


if __name__ == "__main__":
    write_imageset("MenuBarIconOff", back_alpha=140)
    write_imageset("MenuBarIconOn", back_alpha=56)
    print("wrote MenuBarIconOff.imageset and MenuBarIconOn.imageset")
