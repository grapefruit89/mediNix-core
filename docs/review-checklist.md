# Review method

Permanent spec. Not an audit snapshot.

Mark every finding:

| Tag | Meaning |
| --- | --- |
| `[A]` | Eval assertion. If it can fail at rebuild, it must. |
| `[T]` | Automated test (flake check, nixosTest, CI). |
| `[M]` | Human judgment only. Keep these few. |

If a checkbox is `[A]` or `[T]`, do not keep it as a manual list in `audits/`.

Owner of a check is the domain that can enforce it: 511 ingress, 521 creds, 526 VPN, 591 cross-domain, 583 runtime.
