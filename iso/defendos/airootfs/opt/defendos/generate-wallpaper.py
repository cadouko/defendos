#!/usr/bin/env python3
"""DefendOS – Placeholder wallpaper generator
Creates a simple gradient background if no wallpaper.png exists.
"""
import os
WALLPAPER = "/opt/defendos/wallpaper.png"
if not os.path.exists(WALLPAPER):
    try:
        from PIL import Image
        img = Image.new("RGB", (1920, 1080), "#1a1a2e")
        img.save(WALLPAPER)
    except ImportError:
        # Create minimal valid PNG manually
        import zlib, struct
        def make_png(w, h, color):
            raw = b""
            for y in range(h):
                raw += b"\x00" + bytes(color) * w
            def chunk(ctype, data):
                c = ctype + data
                return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)
            sig = b"\x89PNG\r\n\x1a\n"
            ihdr = chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
            idat = chunk(b"IDAT", zlib.compress(raw))
            return sig + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + idat + chunk(b"IEND", b"")
        with open(WALLPAPER, "wb") as f:
            f.write(make_png(1920, 1080, (26, 26, 46)))
