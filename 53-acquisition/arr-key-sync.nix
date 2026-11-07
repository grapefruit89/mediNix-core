# ---
# id: "arr-key-sync"
# title: "ExecStartPre: versiegelten API-Key in die Arr-config.xml schreiben"
# domain: 53
# folder: "53-acquisition"
# status: active
# kind: library
# complexity: 2
# last_reviewed: 2026-11-07
# links:
#   adr: ADR-532
# ---
# Warum es dieses Skript gibt (Messung 2026-11-07 auf q958):
#
#   Die Arr-Apps erzeugen ihren API-Key selbst und schreiben ihn in
#   <state>/config.xml. Ein Env-Override existiert NICHT: weder
#   SONARR__CONFIG__APIKEY (Erstinitialisierung wie bestehende config.xml)
#   noch SONARR__AUTH__APIKEY haben den Wert uebernommen. Die Docker-Variable
#   *_API_KEY_FILE wird vom nativen Binary ebenfalls ignoriert (sie wertet nur
#   der Docker-Entrypoint aus).
#
#   Deshalb kommt der versiegelte Key VOR dem Start in die Datei:
#     - Datei fehlt   -> minimal vorbefuellen. Sonarr startet damit, akzeptiert
#                        den Key (HTTP 200) und vervollstaendigt die Datei.
#     - <ApiKey> da   -> ersetzen.
#     - kein Tag      -> vor </Config> einfuegen.
#
#   Laeuft als User=<dienst> (systemd ExecStartPre) und schreibt damit
#   ausschliesslich in sein eigenes StateDirectory - kein Root, kein Fremdzugriff.
#
# Verifikation: nach dem Start muss config.xml den versiegelten Wert tragen und
# exportarr /metrics HTTP 200 liefern (vorher 500).
{ pkgs, name }:
pkgs.writeShellApplication {
  name = "arr-api-key-sync-${name}";
  runtimeInputs = [
    pkgs.gnugrep
    pkgs.gnused
  ];
  text = ''
    cred="''${CREDENTIALS_DIRECTORY}/${name}-api-key"
    cfg="''${STATE_DIRECTORY}/config.xml"

    if [ ! -r "$cred" ]; then
      echo "arr-key-sync: credential fehlt: $cred" >&2
      exit 1
    fi
    key="$(cat "$cred")"
    if [ -z "$key" ]; then
      echo "arr-key-sync: credential ist leer: $cred" >&2
      exit 1
    fi

    if [ ! -f "$cfg" ]; then
      printf '%s\n' \
        '<?xml version="1.0" encoding="utf-8"?>' \
        '<Config>' \
        "  <ApiKey>$key</ApiKey>" \
        '</Config>' > "$cfg"
      echo "arr-key-sync: $cfg mit dem versiegelten Key angelegt"
    elif grep -q '<ApiKey>' "$cfg"; then
      current="$(sed -n 's:.*<ApiKey>\([^<]*\)</ApiKey>.*:\1:p' "$cfg" | head -n1)"
      if [ "$current" = "$key" ]; then
        echo "arr-key-sync: ApiKey bereits aktuell"
      else
        sed -i "s|<ApiKey>[^<]*|<ApiKey>$key|" "$cfg"
        echo "arr-key-sync: ApiKey in $cfg ersetzt"
      fi
    else
      sed -i "s|</Config>|  <ApiKey>$key</ApiKey>\n</Config>|" "$cfg"
      echo "arr-key-sync: ApiKey in $cfg eingefuegt"
    fi
  '';
}
