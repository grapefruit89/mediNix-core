# ---
# id: "581-alert-ntfy"
# title: "Alert ntfy — Systemd OnFailure crash notifier template"
# domain: 58
# folder: 58-observability
# adr: ADR-581
# status: active
# ---
{
  pkgs,
  ...
}:

let
  alertScript = pkgs.writeShellScript "send-ntfy-crash-alert" ''
    UNIT_NAME="''${1:-unknown}"
    ${pkgs.curl}/bin/curl -sf \
      -H "Title: [mediNix] Unit Failure: $UNIT_NAME" \
      -H "Priority: high" \
      -H "Tags: warning,skull" \
      -d "Dienst $UNIT_NAME ist auf Host unerwartet abgestürzt!" \
      "http://127.0.0.1:5810/alerts" || true
  '';
in
{
  systemd.services."alert-ntfy@" = {
    description = "mediNix Failure Notifier für %i";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${alertScript} %i";
      DynamicUser = true;
      PrivateTmp = true;
    };
  };
}
