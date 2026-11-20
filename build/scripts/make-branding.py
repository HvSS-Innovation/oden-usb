#!/usr/bin/env python3
"""Genererar ODEN-utseendet ur branding/oden-logo.png (körs vid behov, resultatet är incheckat).
  python3 scripts/make-branding.py   (kräver Pillow; se scripts/make-branding.sh för körning i Docker)
Ut: grub splash (1920x1200), skrivbordsbakgrund (1920x1200), ikon (256x256)."""
from PIL import Image, ImageDraw, ImageFilter
import os
here = os.path.dirname(os.path.abspath(__file__)); root = os.path.join(here, "..")
logo = Image.open(os.path.join(root, "branding/oden-logo.png")).convert("RGB")
# Bakgrundsfärg = medel av logons kant (tygets färg), så att logon går ihop med bakgrunden utan söm.
px = logo.load(); w, h = logo.size
edge = [px[x, y] for x in range(0, w, 8) for y in (0, h - 1)] + [px[x, y] for y in range(0, h, 8) for x in (0, w - 1)]
bg = tuple(sum(c[i] for c in edge) // len(edge) for i in range(3))
print("bakgrund", "#%02x%02x%02x" % bg)

def feathered(size, fade):
    """Logon skalad till size x size med mjuka kanter (alfamask)."""
    im = logo.resize((size, size), Image.LANCZOS)
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rectangle([fade, fade, size - fade, size - fade], fill=255)
    return im, m.filter(ImageFilter.GaussianBlur(fade / 2))

def canvas(wd, ht, size, cx, cy):
    c = Image.new("RGB", (wd, ht), bg)
    im, m = feathered(size, size // 8)
    c.paste(im, (cx - size // 2, cy - size // 2), m)
    return c

out = lambda p: os.path.join(root, p)
# GRUB: logon till vänster, menyn till höger (theme.txt). Beskärs mitt på 16:9-skärmar, därför säker yta.
canvas(1920, 1200, 820, 560, 600).save(out("config/config/bootloaders/grub-pc/splash.png"), optimize=True)
# Skrivbord/inloggning: logon centrerad
os.makedirs(out("overlay/usr/share/oden"), exist_ok=True)
canvas(1920, 1200, 760, 960, 600).save(out("overlay/usr/share/oden/background.png"), optimize=True)
# Ikon
os.makedirs(out("overlay/usr/share/icons/hicolor/256x256/apps"), exist_ok=True)
logo.resize((256, 256), Image.LANCZOS).save(out("overlay/usr/share/icons/hicolor/256x256/apps/oden.png"), optimize=True)
open(out("branding/bg-color.txt"), "w").write("#%02x%02x%02x\n" % bg)
