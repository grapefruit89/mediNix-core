import os
f = "59-guardrails/590-core-guardrails.nix"
with open(f, 'r', encoding='utf-8') as file:
    c = file.read()
c = c.replace('jellyfin-5510', 'jellyfin')
with open(f, 'w', encoding='utf-8') as file:
    file.write(c)
