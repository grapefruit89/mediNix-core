#!/usr/bin/env python3
"""llm-bundle.py — one-file context bundle for LLM architecture review."""
import json
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

HISTORICAL_PREFIXES = (
    'docs/audit/', 'docs/archive/', 'docs/learn/', 'docs/patterns/',
    'docs/agents/', 'todo/_archive/', 'todo/_input/', 'todo/done/',
    'docs/audit/2026-11-05/todo-blocks/',
)
HIDE_FROM_DETAIL = (
    'todo/_input/', 'todo/_archive/', 'todo/done/',
)
SKIP_ALWAYS = {
    '.git', 'node_modules', '__pycache__', '.venv', '.cache',
    '.mypy_cache', '.pytest_cache', '.agents', '.claude', '.direnv',
}
SKIP_EXT = {
    '.lock', '.log', '.svg', '.png', '.jpg', '.jpeg', '.gif', '.ico',
    '.woff', '.woff2', '.ttf', '.eot', '.pyc', '.pyo', '.pdf', '.zip',
    '.tar', '.gz', '.webp',
}


def sh(cmd, cwd=REPO):
    try:
        return subprocess.check_output(
            cmd, cwd=cwd, stderr=subprocess.DEVNULL, text=True, timeout=30
        ).strip()
    except Exception:
        return ''


def is_text(p):
    try:
        with open(p, 'rb') as f:
            return b'\0' not in f.read(2048)
    except OSError:
        return False


def count_lines(p):
    try:
        with open(p, 'rb') as f:
            return sum(1 for _ in f)
    except OSError:
        return 0


def nix_meta(p):
    fields = {}
    try:
        with open(p, encoding='utf-8') as f:
            for line in f:
                if not line.startswith('#'):
                    if line.strip() and fields:
                        break
                    continue
                s = line.lstrip('#').strip()
                for k in ('id', 'folder', 'domain', 'status', 'provides', 'requires'):
                    if s.startswith(f'{k}:'):
                        v = s.split(':', 1)[1].strip().strip('"')
                        if v:
                            fields[k] = v
                if s == '---' and 'id' in fields:
                    break
    except (OSError, UnicodeDecodeError):
        pass
    return fields


def iter_files():
    for root, dirs, files in os.walk(REPO):
        rel_root = os.path.relpath(root, REPO)
        if rel_root == '.':
            rel_root = ''
        dirs[:] = sorted(
            d for d in dirs
            if d not in SKIP_ALWAYS
        )
        for f in sorted(files):
            if f.startswith('.') and f not in ('.gitignore', '.envrc'):
                continue
            if Path(f).suffix.lower() in SKIP_EXT:
                continue
            p = Path(root) / f
            yield p.relative_to(REPO), p


def section(title):
    print()
    print('=' * 72)
    print(title)
    print('=' * 72)


def main():
    files = list(iter_files())

    # ---- 1. Meta
    section('1. REPO META')
    print(f'Repo:       {REPO}')
    print(f'Branch:     {sh("git rev-parse --abbrev-ref HEAD")}')
    print(f'Last commit: {sh("git log -1 --format=%h %s")}')
    print(f'Status:     {"clean" if not sh("git status --porcelain") else "dirty"}')
    print(f'Files:      {len(files)}')

    # ---- 2. Top-Level sizes
    section('2. TOP-LEVEL SIZES')
    top = {}
    for rel, p in files:
        parts = rel.parts
        key = parts[0] if len(parts) > 1 else '(root)'
        e = top.setdefault(key, {'files': 0, 'bytes': 0})
        e['files'] += 1
        e['bytes'] += p.stat().st_size
    for k, v in sorted(top.items(), key=lambda x: -x[1]['bytes']):
        print(f'  {k:<28} {v["files"]:>4} files  {v["bytes"]/1024/1024:>7.1f} MB')

    # ---- 3. Folder aggregation (depth 2)
    section('3. FOLDER AGGREGATION (depth 2)')
    folders = {}
    for rel, p in files:
        parts = rel.parts
        key = '/'.join(parts[:2]) if len(parts) > 2 else '/'.join(parts[:1]) if len(parts) > 1 else '(root files)'
        e = folders.setdefault(key, {'files': 0, 'bytes': 0})
        e['files'] += 1
        e['bytes'] += p.stat().st_size
    for k, v in sorted(folders.items()):
        mark = ' [HIST]' if any(k.startswith(p) or k == p.rstrip('/') for p in HISTORICAL_PREFIXES) else ''
        print(f'  {k:<40} {v["files"]:>4} files  {v["bytes"]/1024:>9.1f} KB{mark}')

    # ---- 4. .gitignore
    section('4. .gitignore')
    gi = REPO / '.gitignore'
    if gi.exists():
        for line in gi.read_text().splitlines():
            if line.strip() and not line.startswith('#'):
                print(f'  {line}')
    else:
        print('  (no .gitignore)')

    # ---- 5. Flake outputs
    section('5. FLAKE OUTPUTS')
    flake_out = sh('nix flake show --json 2>/dev/null')
    if flake_out:
        try:
            data = json.loads(flake_out)
            def walk(d, path=''):
                for k, v in d.items():
                    if isinstance(v, dict) and 'type' in v:
                        print(f'  {path}{k}  ({v["type"]})')
                    elif isinstance(v, dict):
                        walk(v, path + k + '.')
            walk(data)
        except json.JSONDecodeError:
            print('  (could not parse)')
    else:
        # Fallback: grep from flake.nix
        flake = (REPO / 'flake.nix').read_text()
        for m in re.finditer(r'^\s*(packages|checks|nixosConfigurations|apps|devShells|overlays|nixosModules)\s*=', flake, re.M):
            print(f'  {m.group(1)}.*')

    # ---- 6. Nix import graph (only module folders)
    section('6. NIX IMPORT GRAPH (50-59 only)')
    for rel, p in files:
        if rel.parts[0] not in [f'{n}-{s}' for n, s in [
            (50, 'core'), (51, 'ingress'), (52, 'security'), (53, 'acquisition'),
            (54, 'processing'), (55, 'playback'), (56, 'exposition'),
            (57, 'maintenance'), (58, 'observability'), (59, 'guardrails'),
        ]]:
            continue
        if p.suffix != '.nix':
            continue
        try:
            content = p.read_text(encoding='utf-8')
        except Exception:
            continue
        imports = set()
        for m in re.finditer(r'import\s+\.{1,2}/([\w./-]+\.nix)', content):
            imports.add(m.group(1))
        if imports:
            print(f'  {rel}')
            for i in sorted(imports):
                print(f'    -> {i}')

    # ---- 7. File age
    section('7. FILE AGE (mtime)')
    now = datetime.now().timestamp()
    ages = {'<7d': 0, '<30d': 0, '<90d': 0, '>90d': 0}
    old_files = []
    for rel, p in files:
        if any(str(rel).startswith(h) for h in HIDE_FROM_DETAIL):
            continue
        age_days = (now - p.stat().st_mtime) / 86400
        if age_days < 7:
            ages['<7d'] += 1
        elif age_days < 30:
            ages['<30d'] += 1
        elif age_days < 90:
            ages['<90d'] += 1
        else:
            ages['>90d'] += 1
            if len(old_files) < 20:
                old_files.append((str(rel), int(age_days)))
    print(f'  <7d:   {ages["<7d"]:>4}')
    print(f'  <30d:  {ages["<30d"]:>4}')
    print(f'  <90d:  {ages["<90d"]:>4}')
    print(f'  >90d:  {ages[">90d"]:>4}')
    print()
    print('  Oldest 20 (still > 90d):')
    for rel, days in sorted(old_files, key=lambda x: -x[1])[:20]:
        print(f'    {days:>5}d  {rel}')

    # ---- 8. Duplicates (same basename)
    section('8. DUPLICATES (same basename, different dir)')
    by_name = {}
    for rel, p in files:
        by_name.setdefault(p.name, []).append(str(rel))
    for name, paths in sorted(by_name.items()):
        if len(paths) >= 3:
            print(f'  {name}  x{len(paths)}')
            for path in paths[:8]:
                print(f'    {path}')
            if len(paths) > 8:
                print(f'    ... and {len(paths) - 8} more')

    # ---- 9. Full tree (detail, minus hidden)
    section('9. FULL TREE (detail, hidden/archive excluded)')
    print('# format: <path> | <bytes> | <lines> | <ext> [<meta>]')
    print()
    for rel, p in files:
        if any(str(rel).startswith(h) for h in HIDE_FROM_DETAIL):
            continue
        size = p.stat().st_size
        lines = count_lines(p) if is_text(p) else '-'
        ext = p.suffix or ''
        parts = [str(rel), str(size), str(lines), ext]
        if ext == '.nix':
            meta = nix_meta(p)
            if meta:
                parts.append(' '.join(f'{k}={v}' for k, v in meta.items()))
        print(' | '.join(parts))

    return 0


if __name__ == '__main__':
    sys.exit(main())
