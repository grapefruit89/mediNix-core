import glob
import re

for file in glob.glob("*/*.nix"):
    with open(file, "r", encoding="utf-8") as f:
        content = f.read()
    
    matches = re.findall(r'systemd\.services\.["]?([a-zA-Z0-9_-]+)["]?', content)
    for m in set(matches):
        if content.count(f'systemd.services.{m}') + content.count(f'systemd.services."{m}"') > 1:
            print(f"{file}: {m}")
