---
name: unraid-ssh-access
description: SSH from Hermes container to Unraid host.
---

# Unraid SSH Access (Hermes → Unraid Host)

## Context
Hermes often runs inside a Docker container on the Unraid host itself (192.168.2.250). The container is isolated — no direct filesystem access to the host, but network access to the host's SSH port (53844) is possible.

## Key Generation in Restricted Containers

If `~/.ssh` is not writable (Permission denied), use `/tmp`:

```bash
cd /tmp && ssh-keygen -t ed25519 -f /tmp/hermes_key -N "" -C "hermes-agent@unraid"
cat /tmp/hermes_key.pub  # Copy this to Unraid
```

Then configure the container to use the key:
```bash
cp /tmp/hermes_key ~/.ssh/id_ed25519 2>/dev/null || true
chmod 600 /tmp/hermes_key  # At least make it unreadable by others
```

## Unraid Authorized Keys Location

**Two methods (pick one):**

### Method A: WebUI (recommended for one-off)
1. Unraid WebUI → **Settings** → **SSH**
2. Scroll to **Authorized Keys**
3. Paste the public key as a new line
4. Click **Apply**

### Method B: Terminal on Unraid
```bash
echo "ssh-ed25519 AAAA... hermes-agent@unraid" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
```

**Important:** Unraid runs as `root`, so the key goes to `/root/.ssh/authorized_keys`, NOT `/home/moritz/.ssh/`.

## Connectivity Test

```bash
ssh -o StrictHostKeyChecking=no -p 53844 root@192.168.2.250 "hostname"
```

If using user `moritz` (configured in Unraid SSH settings):
```bash
ssh -o StrictHostKeyChecking=no -p 53844 moritz@192.168.2.250 "hostname"
```

## Unraid as a Compute Node (installing heavy Python tooling)

The Hermes container is dependency-starved for ML: it lacks `numpy`, `scipy`,
`scikit-learn`, `paramiko`, `sshpass`, and `expect`. Do NOT try to install
BERTopic / sentence-transformers / hdbscan / umap there — there is no pip and
`uv`/`python3 -m venv` are also absent. **Install and run heavy workloads on
Unraid (Tower) instead.**

Unraid's `root` Python 3.12 ships WITHOUT pip. Bootstrap it first:
```bash
ssh -i /tmp/hermes_key -p 53844 root@192.168.2.250 "python3 -m ensurepip --upgrade"
ssh -i /tmp/hermes_key -p 53844 root@192.168.2.250 "python3 -m pip --version"
```
Then create a venv on a persistent Unraid share and install there:
```bash
ssh ... "mkdir -p /mnt/user/data/hermes_knowledge/nixos_vectors && cd \$_ && python3 -m venv venv && source venv/bin/activate && pip install numpy scipy sentence-transformers hdbscan umap-learn bertopic"
```
Run the actual Python job via `ssh ... "cd <dir> && source venv/bin/activate && python script.py"`.

**Password auth is DISABLED on this Unraid.** `sshpass`, `expect`, and
`paramiko` are all unavailable in the container, so you cannot supply a
password from Hermes at all. The ONLY path is key-based auth — get the
container's `/tmp/hermes_key.pub` appended to `/root/.ssh/authorized_keys`
on Unraid (user does it via terminal or WebUI), then connect with `-i /tmp/hermes_key`.

## Common Pitfalls

- **"Too many authentication failures"** → SSH is trying all keys in `~/.ssh`. Use `-o IdentitiesOnly=yes -i /path/to/specific/key`.
- **Permission denied on `~/.ssh`** → Container user is not root. Use `/tmp` for key generation, then copy or reference directly with `-i`.
- **Unraid SSH port** → Default is 22, but Moritz's setup uses `53844`. Always specify `-p 53844`.
- **Key not working after adding** → Unraid may need SSH service restart: `/etc/rc.d/rc.sshd restart`
- **User copies formatting chars** → User may copy `─ bash` or box-drawing chars from chat. Tell them: "Kopiere NUR die Befehlszeile, ohne `bash` oder `─` davor." Provide a single-line command they can paste as-is.
- **"SSH is not running" but port responds** → If `ssh` returns `Permission denied`, SSH IS running. That's an SSH handshake rejection, not a closed port. Closed port = `Connection refused` or `Timeout`. Always test first: `nc -zv 192.168.2.250 53844` before assuming SSH is off.

## User Instruction Format (Critical)

When giving the user commands to run on Unraid:

1. **NEVER** include markdown/decorative chars like `─`, `bash`, ```` before the command.
2. Give a **single-line copy-paste command** when possible:
   ```bash
   mkdir -p ~/.ssh && echo "ssh-ed25519 AAAA... comment" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
   ```
3. If multi-line, use `&&` chaining or explicit `bash -c '...'` for sudo echo.
4. If user pastes and gets `-bash: ─: command not found`, immediately re-send the command as raw text without any formatting hints.

## Container Network Check

If connection fails entirely:
```bash
ip addr show  # Check if container has network
nc -zv 192.168.2.250 53844  # Test port reachability
```

If `ip` command missing, check `/etc/hosts` for Docker bridge IPs.

## Security Note

The private key generated in `/tmp` is world-readable by default. Either:
1. Move it to a protected location after testing, or
2. Delete it after adding to Unraid (generate fresh keys per session if needed)
