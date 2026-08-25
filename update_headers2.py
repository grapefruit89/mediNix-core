import glob
import re
import datetime
from pathlib import Path

today = datetime.datetime.now().strftime("%Y-%m-%d")

template_keys = [
    "id", "title", "domain", "folder", "status", "complexity", 
    "last_reviewed", "links", "provides", "requires", "ports", 
    "upstream_docs", "forum_links", "upstream_github", "nixpkgs_attr", 
    "state_dir", "uds_socket", "systemd_hardened"
]

# We include default.nix and all numbered folders
folders = ["50-core", "51-ingress", "52-security", "53-acquisition", "54-transfer", "55-playback", "56-agents", "57-maintenance", "58-observability", "59-guardrails"]

files_to_process = glob.glob("default.nix")
for folder in folders:
    files_to_process.extend(glob.glob(f"{folder}/*.nix"))

for file_path in files_to_process:
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    match = re.search(r'^((?:#\s*)?---\s*\n.*?\n(?:#\s*)?---\s*\n)', content, re.MULTILINE | re.DOTALL)
    existing_header_str = ""
    body = content
    
    if match:
        existing_header_str = match.group(1)
        body = content[match.end():]
    else:
        # Check if there is an ad-hoc header without ---
        lines = content.split('\n')
        in_header = True
        header_lines = []
        body_lines = []
        for line in lines:
            if in_header and (line.startswith('# id:') or line.startswith('# title:') or (line.startswith('#') and ':' in line and not '{' in line)):
                header_lines.append(line)
            elif in_header and line.startswith('#'):
                header_lines.append(line)
            elif in_header and line.strip() == '':
                pass
            else:
                in_header = False
                body_lines.append(line)
        if any("id:" in x for x in header_lines):
            existing_header_str = "\n".join(header_lines)
            body = "\n".join(body_lines)
        else:
            body = content

    # Parse existing keys
    existing_data = {}
    current_key = None
    for line in existing_header_str.split("\n"):
        line = line.lstrip("#").strip()
        if not line: continue
        if line == "---": continue
        if ":" in line and not line.startswith(" "):
            # Split only on first colon
            k, v = line.split(":", 1)
            current_key = k.strip()
            existing_data[current_key] = [v.strip()]
        elif current_key and line.startswith(" "):
            # Continuation line
            existing_data[current_key].append(line)

    # Infer basic data
    file_name = Path(file_path).stem
    
    if file_path == "default.nix":
        domain = "50"
        folder = "50-core"
    else:
        folder_name = Path(file_path).parent.name
        domain = file_name[:2] if file_name[:2].isdigit() else folder_name[:2]
        folder = folder_name

    new_header = []
    new_header.append("# ---")
    
    def add_val(k, default):
        if k in existing_data:
            new_header.append(f"# {k}: {existing_data[k][0]}")
            for extra in existing_data[k][1:]:
                new_header.append(f"# {extra}")
            del existing_data[k]
        else:
            new_header.append(f"# {k}: {default}")

    add_val("id", f'"{file_name}"')
    
    # special handling to preserve old title if missing
    default_title = f'"{file_name} module"'
    add_val("title", default_title)
    
    add_val("domain", domain)
    add_val("folder", folder)
    add_val("status", "active")
    add_val("complexity", "3")
    add_val("last_reviewed", today)
    
    # links is usually empty in default, but let's check existing_data
    if "links" in existing_data:
        add_val("links", existing_data["links"][0])
    else:
        add_val("links", "")
        
    add_val("provides", "[]")
    add_val("requires", '["lib/registry"]')
    add_val("ports", "[]")
    add_val("upstream_docs", "[]")
    add_val("forum_links", "[]")
    add_val("upstream_github", '""')
    add_val("nixpkgs_attr", '""')
    add_val("state_dir", '""')
    add_val("uds_socket", "false")
    add_val("systemd_hardened", "true")

    # Add any remaining (like context7, adr, skill)
    for k, v in existing_data.items():
        new_header.append(f"# {k}: {v[0]}")
        for extra in v[1:]:
            new_header.append(f"# {extra}")

    new_header.append("# ---")
    
    final_content = "\n".join(new_header) + "\n\n" + body.lstrip('\n')

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(final_content)
    
print(f"Updated headers in {len(files_to_process)} nix files.")
