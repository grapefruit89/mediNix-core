import glob
import re
import datetime
from pathlib import Path

folders = ["50-core", "51-ingress"]
today = datetime.datetime.now().strftime("%Y-%m-%d")

template_keys = [
    "id", "title", "domain", "folder", "status", "complexity", 
    "last_reviewed", "links", "provides", "requires", "ports", 
    "upstream_docs", "forum_links", "upstream_github", "nixpkgs_attr", 
    "state_dir", "uds_socket", "systemd_hardened"
]

for folder in folders:
    for file_path in glob.glob(f"{folder}/*.nix"):
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Extract existing header if any
        existing_header_str = ""
        body = content
        match = re.search(r'^(?:#\s*)?---\s*\n(.*?)\n(?:#\s*)?---\s*\n', content, re.MULTILINE | re.DOTALL)
        if match:
            existing_header_str = match.group(1)
            body = content[match.end():]
        else:
            # Maybe it doesn't have `---` but just `# id: ...` at top
            lines = content.split('\n')
            header_lines = []
            body_lines = []
            in_header = True
            for line in lines:
                if in_header and (line.startswith('# id:') or line.startswith('# title:') or line.startswith('#') and ':' in line):
                    header_lines.append(line.lstrip('#').strip())
                elif in_header and line.startswith('#'):
                    # Could be just a comment
                    pass
                elif in_header and line.strip() == '':
                    pass
                else:
                    in_header = False
                    body_lines.append(line)
            # If no clear header found, reset body
            if not any("id:" in x for x in header_lines):
                body = content
            else:
                existing_header_str = "\n".join(header_lines)
                body = "\n".join(body_lines)

        # Parse existing keys manually
        existing_data = {}
        current_key = None
        for line in existing_header_str.split("\n"):
            if not line.strip(): continue
            if ":" in line and not line.startswith(" "):
                k, v = line.split(":", 1)
                current_key = k.strip()
                existing_data[current_key] = [v.strip()]
            elif current_key and line.startswith(" "):
                existing_data[current_key].append(line)

        # Infer basic data
        file_name = Path(file_path).stem
        domain = file_name[:2] if file_name[:2].isdigit() else folder[:2]
        
        # Build new header
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
        add_val("title", f'"{file_name} module"')
        add_val("domain", domain)
        add_val("folder", folder)
        add_val("status", "active")
        add_val("complexity", "3")
        add_val("last_reviewed", today)
        add_val("links", "")
        # Add sub-links if they weren't in existing
        # This is basic textual generation.
        
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

        # Add any remaining context7 etc
        for k, v in existing_data.items():
            if k not in template_keys:
                new_header.append(f"# {k}: {v[0]}")
                for extra in v[1:]:
                    new_header.append(f"# {extra}")

        new_header.append("# ---")
        
        final_content = "\n".join(new_header) + "\n\n" + body.lstrip('\n')

        with open(file_path, "w", encoding="utf-8") as f:
            f.write(final_content)
        print(f"Updated header in {file_path}")

