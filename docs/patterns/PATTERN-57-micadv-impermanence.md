---
id: "PATTERN-57-micadv-impermanence"
title: "PATTERN 5700 micadv impermanence"
domain: 57
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - impermanence
  - storage
links:
  adr: ""
  repo-harvest: ""
---
Me trying to make impermance work with userborn.
Can be tested like this:

```
$ nix run github:Mic92/userborn-with-impermanence#nixosConfigurations.myhost.config.system.build.vmWithDisko
```

## Current issues

- [x] ~~`environment.persistence.<mountpoint>.users.<user>.directories` have the wrong user/group.~~, see https://github.com/nix-community/impermanence/pull/223

