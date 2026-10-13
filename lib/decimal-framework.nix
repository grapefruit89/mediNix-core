# ---
# id: "decimal-framework"
# title: "SSoT for Decimal Numbering Framework (ADR-0000)"
# domain: 50
# folder: lib
# status: active
# ---
_:

rec {
  deconstruct = n: rec {
    id = n;
    project = n / 100;
    decade = (n - (project * 100)) / 10;
    slot = n - (project * 100) - (decade * 10);
  };

  derive =
    name: n:
    let
      parts = deconstruct n;
    in
    {
      inherit (parts)
        id
        project
        decade
        slot
        ;
      port = n * 10;
      uid = n * 10;
      gid = parts.project * 1000;
      stateDir = "/var/lib/${name}-${toString (n * 10)}";
      group = if parts.project == 5 then "media" else "proj-${toString parts.project}";
    };

  validate =
    name: n:
    let
      d = derive name n;
    in
    [
      {
        assertion = n >= 100 && n <= 999;
        message = "[ADR-0000] Dienst '${name}' (${toString n}) muss 3-stellig sein (100–999).";
      }
      {
        assertion = d.decade != 0;
        message = "[ADR-0000] Dienst '${name}' liegt in Dekade 0 (${toString n}). Dekade 0 ist Foundation und verbietet Daemons.";
      }
      {
        assertion = (d.slot != 0) || (name == "gatus");
        message = "[ADR-0000] Slot 0 (${toString n}) ist eine Block-ID, kein Service.";
      }
      {
        assertion = d.port > 1023 && d.port < 32768;
        message = "[ADR-0000] Port ${toString d.port} verletzt das sichere Server-Band (1024–32767).";
      }
      {
        assertion = d.uid != d.gid;
        message = "[ADR-0000] UID (${toString d.uid}) kollidiert mit GID (${toString d.gid}).";
      }
    ];
}
