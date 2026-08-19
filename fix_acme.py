import os
acme_file = "51-ingress/514-acme.nix"
with open(acme_file, 'r', encoding='utf-8') as f:
    c = f.read()

repl = '''lib.mkIf (cfg.enable && ing.enable && acmeHost != null) {

  assertions = [
    {
      assertion = credPath != null || plainTokenFile != null;
      message = "ACME Host is set, but no Cloudflare token credential or plain file is provided. This would fail silently at runtime.";
    }
  ];'''

c = c.replace('lib.mkIf (cfg.enable && ing.enable && acmeHost != null) {', repl)
with open(acme_file, 'w', encoding='utf-8') as f:
    f.write(c)
