"""Render Terax's code-native arrow mark. Requires Pillow only to regenerate."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
canvas = Image.new('RGBA', (1024, 1024), (16, 23, 25, 255))
draw = ImageDraw.Draw(canvas)
draw.rounded_rectangle((90, 90, 934, 934), radius=240, fill='#75E2C3')
draw.line([(340, 684), (684, 340)], fill='#082A22', width=70)
draw.line([(420, 340), (684, 340), (684, 604)], fill='#082A22', width=70, joint='curve')

for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    target = ROOT / 'android/app/src/main/res' / f'mipmap-{density}' / 'ic_launcher.png'
    canvas.resize((size, size), Image.Resampling.LANCZOS).save(target)
canvas.save(ROOT / 'windows/runner/resources/app_icon.ico', sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
