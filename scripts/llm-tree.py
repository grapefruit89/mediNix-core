#!/usr/bin/env python3
"""llm-tree.py — token-efficient repo snapshot for LLM consumption.

Usage:
    python3 scripts/llm-tree.py            # active project only
    python3 scripts/llm-tree.py --full     # include historical docs
    python3 scripts/llm-tree.py --json     # machine-readable
    python3 scripts/llm-tree.py --no-meta  # skip YAML header extraction
"""
import argparse
import json
import os
import sys
from pathlib import Path

SKIP_ALWAYS = {
    '.git', 'node_modules', '__pycache__', '.venv', '.cache',
    '.mypy_cache', '.pytest_cache', '.agents', '.claude', '.direnv',
}
SKIP_HISTORICAL = {
    'docs/audit', 'docs/archive', 'docs/learn',
    'docs/agents', 'todo',
}
SKIP_EXT = {
    '.lock', '.log', '.svg', '.png', '.jpg', '.jpeg', '.gif', '.ico',
    '.woff', '.woff2', '.ttf', '.eot', '.pyc', '.pyo', '.pdf', '.zip',
    '.tar', '.gz', '.webp',
}


def is_text(path: Path) -> bool:
    try:
        with open(path, 'rb') as f:
            return b'\0' not in f.read(2048)
    except OSError:
        return False


def count_lines(path: Path) -> int:
    try:
        with open(path, 'rb') as f:
            return sum(1 for _ in f)
    except OSError:
        return 0


def nix_meta(path: Path) -> str:
    """Extract YAML header fields from a .nix file."""
    fields = {}
    try:
        with open(path, encoding='utf-8') as f:
            for line in f:
                if not line.startswith('#'):
                    if line.strip() and fields:
                        break
                    continue
                stripped = line.lstrip('#').strip()
                for key in ('id', 'folder', 'domain', 'status'):
                    if stripped.startswith(f'{key}:'):
                        val = stripped.split(':', 1)[1].strip().strip('"')
                        if val:
                            fields[key] = val
                if stripped == '---' and 'id' in fields:
                    break
    except (OSError, UnicodeDecodeError):
        pass
    return ' '.join(f'{k}={v}' for k, v in fields.items())


def should_skip_dir(rel: str, full: bool) -> bool:
    if not full:
        for s in SKIP_HISTORICAL:
            if rel == s or rel.startswith(s + '/'):
                return True
    return False


def walk(repo: Path, full: bool):
    for root, dirs, files in os.walk(repo):
        rel_root = os.path.relpath(root, repo)
        if rel_root == '.':
            rel_root = ''
        dirs[:] = sorted(
            d for d in dirs
            if d not in SKIP_ALWAYS
            and not should_skip_dir(f'{rel_root}/{d}'.lstrip('/'), full)
        )
        for f in sorted(files):
            if f.startswith('.'):
                continue
            ext = Path(f).suffix.lower()
            if ext in SKIP_EXT:
                continue
            path = Path(root) / f
            yield path.relative_to(repo), path


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument('--full', action='store_true',
                   help='Include historical docs (audit, archive, learn, patterns, agents, todo)')
    p.add_argument('--no-meta', action='store_true',
                   help='Skip YAML header extraction')
    p.add_argument('--json', action='store_true',
                   help='Output as JSON')
    p.add_argument('--repo', default='.', help='Repo root')
    args = p.parse_args()

    repo = Path(args.repo).resolve()
    if not (repo / 'flake.nix').exists():
        print(f'error: {repo} does not look like a mediNix-core repo', file=sys.stderr)
        return 1

    entries = list(walk(repo, full=args.full))

    if args.json:
        result = []
        for rel, path in entries:
            size = path.stat().st_size
            lines = count_lines(path) if is_text(path) else None
            item = {
                'path': str(rel),
                'bytes': size,
                'lines': lines,
                'ext': rel.suffix or '',
            }
            if rel.suffix == '.nix' and not args.no_meta:
                meta = nix_meta(path)
                if meta:
                    item['meta'] = meta
            result.append(item)
        print(json.dumps(result, indent=2))
        return 0

    mode = 'full' if args.full else 'active-only'
    print(f'# LLM Tree — {mode}')
    print(f'# Repo: {repo}')
    print(f'# Files: {len(entries)}')
    print()

    by_ext = {}
    by_ext_bytes = {}
    for rel, path in entries:
        ext = rel.suffix or '(none)'
        by_ext[ext] = by_ext.get(ext, 0) + 1
        by_ext_bytes[ext] = by_ext_bytes.get(ext, 0) + path.stat().st_size

    print('## Breakdown by extension')
    for ext, n in sorted(by_ext.items(), key=lambda x: -x[1]):
        kb = by_ext_bytes[ext] / 1024
        print(f'  {ext:<12} {n:>4} files  {kb:>8.1f} KB')
    print()

    print('## Files')
    print('# format: <path> | <bytes> | <lines> | <ext> [<meta>]')
    print()
    for rel, path in entries:
        size = path.stat().st_size
        lines = count_lines(path) if is_text(path) else '-'
        ext = rel.suffix or ''
        meta = ''
        if ext == '.nix' and not args.no_meta:
            meta = nix_meta(path)
        parts = [str(rel), str(size), str(lines), ext]
        if meta:
            parts.append(meta)
        print(' | '.join(parts))

    return 0


if __name__ == '__main__':
    sys.exit(main())
