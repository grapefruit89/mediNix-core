import glob
import re

for file in glob.glob("*/*.nix"):
    with open(file, "r", encoding="utf-8") as f:
        content = f.read()
    
    matches = re.findall(r"systemd\.services\.([a-zA-Z0-9_-]+)(?:\s*=|\[|\.)", content)
    # We want to find files where `systemd.services.foo = {` and `systemd.services.foo.requires =` appear in the SAME attrset block.
    # Actually, it's easier to just grep for `systemd.services.` and see manually or use regex to fix them.
    for m in set(matches):
        if content.count(f"systemd.services.{m}") > 1:
            print(f"{file}: multiple systemd.services.{m}")
            
