# Draws the Repairwala launcher icon: a white wrench crossed by an orange lightning bolt
# on the app's dark green. Writes a 1024px foreground (transparent), a full legacy icon,
# and a preview sheet. Usage: python app/tool/make_icon.py <out_dir> (needs Pillow),
# then resize into android/app/src/main/res/mipmap-*.
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

GREEN = (46, 71, 66)
ORANGE = (245, 140, 20)
WHITE = (255, 255, 255)
N = 1024
SS = 4  # supersampling for smooth edges

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)


def wrench_mask(size):
    """White wrench on black, horizontal, head on the right, centred."""
    s = size / N
    m = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(m)
    cx, cy = size / 2 - 32 * s, size / 2  # artwork spans -330..395, so shift it to centre
    def X(v): return cx + v * s
    def Y(v): return cy + v * s
    # handle
    d.rounded_rectangle([X(-330), Y(-62), X(160), Y(62)], radius=62 * s, fill=255)
    # head
    d.ellipse([X(230 - 165), Y(-165), X(230 + 165), Y(165)], fill=255)
    # jaw opening (cut), rounded at the bottom of the slot
    d.rectangle([X(230), Y(-62), X(420), Y(62)], fill=0)
    d.ellipse([X(230 - 62), Y(-62), X(230 + 62), Y(62)], fill=0)
    # hanging hole in the handle
    d.ellipse([X(-268 - 30), Y(-30), X(-268 + 30), Y(30)], fill=0)
    return m


def bolt_polygon(size, scale=1.0, dx=0, dy=0):
    s = size / N * scale
    pts = [(60, -330), (-170, 50), (-15, 50), (-90, 330), (180, -80), (25, -80), (130, -330)]
    return [(size / 2 + (x + dx) * s, size / 2 + (y + dy) * s) for x, y in pts]


def foreground(size):
    big = size * SS
    img = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    # wrench, scaled into the adaptive-icon safe zone and leaning the other way from the bolt
    w = wrench_mask(big).rotate(135, resample=Image.BICUBIC, center=(big / 2, big / 2))
    w = w.resize((int(big * 0.70),) * 2, Image.LANCZOS)
    wm = Image.new('L', (big, big), 0)
    off = (big - w.width) // 2
    wm.paste(w, (off, off))
    img.paste(Image.new('RGBA', (big, big), WHITE + (255,)), (0, 0), wm)
    # bolt with a green outline so it reads on top of the wrench
    d = ImageDraw.Draw(img)
    poly = bolt_polygon(big, scale=0.74)
    d.polygon(poly, fill=ORANGE + (255,), outline=GREEN + (255,), width=int(22 * big / N))
    return img.resize((size, size), Image.LANCZOS)


fg = foreground(N)
fg.save(out / 'foreground.png')

# legacy (pre-Android 8) icon: what a launcher shows of the adaptive icon, as a rounded square
full = Image.new('RGBA', (N, N), GREEN + (255,))
full.alpha_composite(fg)
full = full.crop((N // 6, N // 6, N - N // 6, N - N // 6)).resize((N, N), Image.LANCZOS)
mask = Image.new('L', (N * SS, N * SS), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, N * SS - 1, N * SS - 1], radius=220 * SS, fill=255)
mask = mask.resize((N, N), Image.LANCZOS)
legacy = Image.new('RGBA', (N, N), (0, 0, 0, 0))
legacy.paste(full, (0, 0), mask)
legacy.save(out / 'legacy.png')

# preview: circle and squircle masks as launchers show them, plus small size
sheet = Image.new('RGB', (3 * 340 + 40, 380), (240, 240, 240))
for i, shape in enumerate(['circle', 'squircle']):
    mk = Image.new('L', (N, N), 0)
    dd = ImageDraw.Draw(mk)
    (dd.ellipse if shape == 'circle' else lambda b, fill: dd.rounded_rectangle(b, radius=300, fill=fill))([0, 0, N - 1, N - 1], fill=255)
    t = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    t.paste(full, (0, 0), mk)
    sheet.paste(t.resize((300, 300), Image.LANCZOS), (20 + i * 340, 40), t.resize((300, 300), Image.LANCZOS))
small = legacy.resize((96, 96), Image.LANCZOS)
sheet.paste(small, (20 + 2 * 340 + 100, 140), small)
sheet.save(out / 'preview.png')
print('ok')
