import os

files = {
    '51-ingress/512-pocket-id.nix': 'public',
    '53-acquisition/532-sonarr.nix': 'internal',
    '53-acquisition/533-radarr.nix': 'internal',
    '53-acquisition/534-readarr.nix': 'internal',
    '53-acquisition/535-lidarr.nix': 'internal',
    '53-acquisition/536-prowlarr.nix': 'internal',
    '54-transfer/541-sabnzbd.nix': 'internal',
    '55-playback/551-jellyfin.nix': 'stream',
    '55-playback/552-audiobookshelf.nix': 'stream',
    '55-playback/553-navidrome.nix': 'stream',
    '55-playback/555-jellyseerr.nix': 'public',
    '58-observability/581-ntfy.nix': 'public'
}

for path, access in files.items():
    name = path.split('/')[-1].split('-')[1].split('.')[0]
    if 'pocket' in path: name = 'pocket-id'
    elif 'jellyfin' in path: name = 'jellyfin'
    elif 'sabnzbd' in path: name = 'sabnzbd'
    elif 'audiobookshelf' in path: name = 'audiobookshelf'
    elif 'jellyseerr' in path: name = 'jellyseerr'
    elif 'ntfy' in path: name = 'ntfy'
    
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find the last '}'
    idx = content.rfind('}')
    if idx != -1:
        insert = f'\n  grapefruitMedia.ingress.vhosts."{name}" = {{ accessGroup = "{access}"; }};\n'
        new_content = content[:idx] + insert + content[idx:]
        with open(path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {path}")
    else:
        print(f"Could not find }} in {path}")
