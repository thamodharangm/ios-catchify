import json
import os
from PIL import Image

src_path = 'assets/icons/appicon3.png'
appiconset_dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
contents_json_path = os.path.join(appiconset_dir, 'Contents.json')

with open(contents_json_path, 'r') as f:
    contents = json.load(f)

img = Image.open(src_path).convert('RGBA')

# iOS App Store / marketing icon must not have alpha transparency
# Create an opaque RGB image on black/white background or keep RGB
for item in contents.get('images', []):
    filename = item.get('filename')
    if not filename:
        continue
    
    size_str = item['size'] # e.g. "20x20", "83.5x83.5"
    scale_str = item['scale'] # e.g. "1x", "2x", "3x"
    
    base_w, base_h = [float(x) for x in size_str.split('x')]
    scale = float(scale_str.replace('x', ''))
    
    target_w = int(round(base_w * scale))
    target_h = int(round(base_h * scale))
    
    # Resize with high quality Lanczos filter
    resized = img.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    # iOS marketing icon 1024x1024 must be RGB (no alpha)
    if target_w == 1024 and target_h == 1024:
        bg = Image.new('RGB', (1024, 1024), (20, 20, 20))
        bg.paste(resized, mask=resized.split()[3])
        out_img = bg
    else:
        out_img = resized
        
    out_path = os.path.join(appiconset_dir, filename)
    out_img.save(out_path, 'PNG')
    print(f"Generated {filename} ({target_w}x{target_h})")

print("All iOS AppIcons generated successfully from appicon3.png!")
