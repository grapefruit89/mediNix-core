import os
import re

files = [
    "53-acquisition/532-sonarr.nix",
    "53-acquisition/533-radarr.nix",
    "53-acquisition/534-readarr.nix",
    "53-acquisition/535-lidarr.nix",
    "53-acquisition/536-prowlarr.nix",
    "54-transfer/541-sabnzbd.nix",
    "55-playback/551-jellyfin.nix",
    "55-playback/552-audiobookshelf.nix",
    "55-playback/553-navidrome.nix",
    "55-playback/554-feishin.nix",
    "55-playback/555-jellyseerr.nix"
]

for filepath in files:
    if not os.path.exists(filepath): continue
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Fix the opening lib.mkIf cfg.enable { -> lib.mkIf cfg.enable (lib.mkMerge [
    if "lib.mkIf cfg.enable {" in content:
        content = content.replace("lib.mkIf cfg.enable {", "lib.mkIf cfg.enable (lib.mkMerge [")
        # And the closing brace at the end of the file must be replaced by ])
        # We find the last `}` and replace it.
        # But some files have extra `};` at the end (like prowlarr).
        content = re.sub(r'\}\s*(\}\s*;)?\s*$', '])\n', content)

    # 2. Fix `systemd.services.<name> = (mkService { ... }).systemd.services.<name> // {`
    # -> `(mkService { ... })` and `{ systemd.services.<name> = lib.mkMerge [ {`
    name_match = re.search(r'systemd\.services\.([a-z0-9-]+)\s*=\s*\(mkService\s*\{', content)
    if name_match:
        name = name_match.group(1)
        # We want to replace `systemd.services.foo = (mkService {` with `(mkService {`
        content = re.sub(r'systemd\.services\.' + name + r'\s*=\s*\(mkService', r'(mkService', content)
        
        # Then we find `}).systemd.services.foo // {` and replace with `}) { systemd.services.foo = lib.mkMerge [ {`
        content = re.sub(r'\}\)\.systemd\.services\.' + name + r'\s*//\s*\{', r'}) { systemd.services.' + name + r' = lib.mkMerge [ {', content)
        
        # Now we need to close the lib.mkMerge [ { ... } ] before the sockets or ingress.
        # The block we opened with `{` ends before `systemd.sockets.` or `grapefruitMedia.ingress.`
        # Actually, it's easier to find the end of `systemd.services.foo = lib.mkMerge [ { ... ` which is a `};` 
        # and replace it with `} ] ;`
        # Let's find the `};` that is followed by `systemd.sockets` or `grapefruitMedia` or `systemd.services."`
        content = re.sub(r'(\n\s*)\};\s*\n(\s*(?:systemd\.sockets|grapefruitMedia\.ingress|systemd\.services\.|#))', r'\1} ];\n\2', content)

    # 3. Fix the duplicate `systemd.services."<name>"` at the bottom.
    # systemd.services."<name>" = lib.mkIf (cfg.secrets.*ApiKeyFile != null) { ... };
    # We will move this into the lib.mkMerge we just created, or just merge it properly.
    # Wait, the duplicate is `systemd.services."foo" = lib.mkIf ...` 
    # Since we are already inside a global `{ ... }` (because we changed `}) { systemd.services.foo = ...`), 
    # the second `systemd.services."foo"` will clash.
    # Let's fix `cfg.secrets.` to `svc.secrets.` first.
    content = content.replace("cfg.secrets.", "svc.secrets.")
    content = content.replace("cfg.apiKeyFile", "svc.secrets." + name + "ApiKeyFile")
    
    # 4. Remove the extra parens/braces in prowlarr
    if "prowlarr" in filepath:
        content = content.replace("  };\n\n}", "}") # cleaned above by regex, but just in case
    
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)
