# mediNix-core AGENTS.md / Global Rules

This repository relies on NixOS and has strict modularity and security invariant rules. All agents modifying code in this repository MUST follow these rules:

1. **NO BATCH SCRIPT REPLACEMENTS**: When modifying `.nix` files, you MUST use precise file edit tools (like `replace_file_content` or similar old_string -> new_string diffing tools). **NEVER** write Python, PowerShell, or Bash scripts using regex/replace to perform batch edits across files. If a change affects multiple files, you must edit each file individually and verify the diff.
2. **ASSERTIONS SAFETY**: After modifying any `assertions = [ ... ]` block, you must explicitly verify that you have not accidentally truncated or deleted assertions. The evaluator is our safety net, do not break it.
3. **READ FOLDER WIKIS**: Before you make ANY modifications to files inside a `5x-*` folder, you MUST read the `AGENTS.md` file located inside that folder. It contains the architecture domain, module map, and dependency requirements. Do not guess dependencies.
4. **NO PLEX**: Plex is banned. Use Jellyfin.
5. **ZERO TRUST LOCALHOST**: Never trust the LAN. All services must have explicit nftables restrictions or reverse-proxy authentication where applicable.
