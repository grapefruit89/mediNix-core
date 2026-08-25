# ---
# id: "572-recyclarr"
# title: "Recyclarr - TRaSH-Guides Sync (Declarative)"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 3
# last_reviewed: 2026-08-19
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.maintenance.recyclarr;
  svc = config.medinix;
  portRadarr = (import ../lib/registry.nix { inherit lib; }).services.radarr.port;
  portSonarr = (import ../lib/registry.nix { inherit lib; }).services.sonarr.port;

  germanProfile = {
    name = "German 1080p HEVC";
    min_format_score = 10000;
    upgrade = {
      allowed = true;
      until_quality = "1080p";
      until_score = 35000;
    };
    quality_sort = "top";
    qualities = [
      {
        name = "1080p";
        qualities = [ "WEBDL-1080p" "WEBRip-1080p" ];
      }
    ];
    reset_unmatched_scores.enabled = true;
  };

  englishProfile = {
    name = "English 1080p HEVC";
    min_format_score = 0;
    upgrade = {
      allowed = true;
      until_quality = "1080p";
      until_score = 10000;
    };
    quality_sort = "top";
    qualities = [
      {
        name = "1080p";
        qualities = [ "WEBDL-1080p" "WEBRip-1080p" ];
      }
    ];
    reset_unmatched_scores.enabled = true;
  };

  web1080pSizeLimits = [
    { name = "WEBDL-1080p";  min = 12.5; preferred = 50; max = 75; }
    { name = "WEBRip-1080p"; min = 12.5; preferred = 50; max = 75; }
  ];

  movieQualityDefinition = {
    type = "movie";
    qualities = web1080pSizeLimits;
  };

  seriesQualityDefinition = {
    type = "series";
    qualities = web1080pSizeLimits;
  };

  customFormats = [
    {
      trash_ids = [ "f845be10da4f442654c13e1f2c3d6cd5" ]; # German DL
      assign_scores_to = [
        { name = "German 1080p HEVC"; score = 11000; }
        { name = "English 1080p HEVC"; score = -10000; }
      ];
    }
    {
      trash_ids = [ "86bc3115eb4e9873ac96904a4a68e19e" ]; # German
      assign_scores_to = [
        { name = "German 1080p HEVC"; score = 10000; }
        { name = "English 1080p HEVC"; score = -10000; }
      ];
    }
    {
      trash_ids = [ "4eadb75fb23d09dfc0a8e3f687e72287" ]; # Not German or English
      assign_scores_to = [
        { name = "German 1080p HEVC"; score = -35000; }
        { name = "English 1080p HEVC"; score = -35000; }
      ];
    }
    {
      trash_ids = [ "9170d55c319f4fe40da8711ba9d8050d" ]; # x265/HEVC
      assign_scores_to = [
        { name = "German 1080p HEVC"; score = 500; }
        { name = "English 1080p HEVC"; score = 500; }
      ];
    }
    {
      trash_ids = [ "ed38b889b31be83fda192888e2286d83" ]; # BR-Disk
      assign_scores_to = [
        { name = "German 1080p HEVC"; score = -35000; }
        { name = "English 1080p HEVC"; score = -35000; }
      ];
    }
    {
      trash_ids = [ "90a6f9a284dff5103f6346090e6280c8" ]; # LQ
      assign_scores_to = [
        { name = "German 1080p HEVC"; score = -35000; }
        { name = "English 1080p HEVC"; score = -35000; }
      ];
    }
  ];

in lib.mkIf cfg.enable {
  services.recyclarr = {
    enable = true;
    configuration = lib.mkMerge [
      (lib.mkIf svc.sonarr.enable {
        sonarr.sonarr = {
          base_url = "http://127.0.0.1:${toString portSonarr}";
          api_key._secret = "/run/credentials/recyclarr.service/sonarr-api-key";
          delete_old_custom_formats = true;
          quality_definition = seriesQualityDefinition;
          quality_profiles = [ germanProfile englishProfile ];
          custom_formats = customFormats;
        };
      })
      (lib.mkIf svc.radarr.enable {
        radarr.radarr = {
          base_url = "http://127.0.0.1:${toString portRadarr}";
          api_key._secret = "/run/credentials/recyclarr.service/radarr-api-key";
          delete_old_custom_formats = true;
          quality_definition = movieQualityDefinition;
          quality_profiles = [ germanProfile englishProfile ];
          custom_formats = customFormats;
        };
      })
    ];
  };

  systemd.services.recyclarr = {
    serviceConfig.LoadCredentialEncrypted = lib.mkMerge [
      (lib.mkIf svc.radarr.enable [ "radarr-api-key:${svc.secrets.radarrApiKeyFile}" ])
      (lib.mkIf svc.sonarr.enable [ "sonarr-api-key:${svc.secrets.sonarrApiKeyFile}" ])
    ];
  };
}
