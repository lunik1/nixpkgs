{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.inadyn;

  # check if a value of an attrset is not null or an empty collection
  nonEmptyValue = _: v: ! isNull v && v != [ ] && v != { };

  renderOption = k: v:
    if builtins.elem k [ "provider" "custom" ] then
      lib.concatStringsSep "\n"
        (mapAttrsToList
          (name: config: ''
            ${k} ${name} {
                ${lib.concatStringsSep "\n    " (mapAttrsToList renderOption (filterAttrs nonEmptyValue config))}
            }'')
          v)
    else if k == "include" then
      "${k}(\"${v}\")"
    else if k == "hostname" && builtins.isList v then
      "${k} = { ${builtins.concatStringsSep ", " (map (s: "\"${s}\"") v)} }"
    else if builtins.isBool v then
      "${k} = ${boolToString v}"
    else if builtins.isString v then
      "${k} = \"${v}\""
    else
      "${k} = ${toString v}";

  configFile' = pkgs.writeText "inadyn.conf"
    ''
    # This file was generated by nix
    # do not edit

    ${(lib.concatStringsSep "\n" (mapAttrsToList renderOption (filterAttrs nonEmptyValue cfg.settings)))}
    '';

  configFile = if (cfg.configFile != null) then cfg.configFile else configFile';
in
{
  options.services.inadyn = with types;
    let providerOptions =
      {
        include = mkOption {
          default = null;
          description = mdDoc "File to include additional settings for this provider from.";
          type = nullOr path;
        };
        ssl = mkOption {
          default = true;
          description = mdDoc "Whether to use HTTPS for this DDNS provider.";
          type = bool;
        };
        username = mkOption {
          default = null;
          description = mdDoc "Username for this DDNS provider.";
          type = nullOr str;
        };
        password = mkOption {
          default = null;
          description = mdDoc ''
            Password for this DDNS provider.

            WARNING: This will be world-readable in the nix store.
            To store credentials securely, use the `include` or `configFile` options.
          '';
          type = nullOr str;
        };
        hostname = mkOption {
          default = "*";
          example = "your.cool-domain.com";
          description = mdDoc "Hostname alias(es).";
          type = either str (listOf str);
        };
      };
    in
    {
      enable = mkEnableOption (mdDoc ''
        Whether to synchronise your machine's IP address with a dynamic DNS provider using inadyn.
      '');
      interval = mkOption {
        default = "*-*-* *:*:00";
        description = mdDoc "How often to check the current IP.";
        type = str;
      };
      settings = mkOption {
        default = { };
        description = "See `inadyn.conf (5)`";
        type = submodule {
          freeformType = attrs;
          options = {
            allow-ipv6 = mkOption {
              default = config.networking.enableIPv6;
              defaultText = "`config.networking.enableIPv6`";
              description = mdDoc "Whether to get IPv6 addresses from interfaces.";
              type = bool;
            };
            forced-update = mkOption {
              default = 2592000;
              description = mdDoc "Duration (in seconds) after which an update is forced.";
              type = ints.positive;
            };
            provider = mkOption {
              default = { };
              description = mdDoc ''
                Settings for DDNS providers built-in to inadyn.

                For a list of built-in providers, see `inadyn.conf (5)`.
              '';
              type = attrsOf (submodule {
                freeformType = attrs;
                options = providerOptions;
              });
            };
            custom = mkOption {
              default = { };
              description = mdDoc ''
                Settings for custom DNS providers.
              '';
              type = attrsOf (submodule {
                freeformType = attrs;
                options = providerOptions // {
                  ddns-server = mkOption {
                    description = mdDoc "DDNS server name.";
                    type = str;
                  };
                  ddns-path = mkOption {
                    description = mdDoc ''
                      DDNS server path.

                      See `inadnyn.conf (5)` for a list for format specifiers that can be used.
                    '';
                    example = "/update?user=%u&password=%p&domain=%h&myip=%i";
                    type = str;
                  };
                };
              });
            };
          };
        };
      };
      configFile = mkOption {
        default = null;
        description = mdDoc ''
          Configuration file for inadyn.

          Setting this will override all other configuration options.

          Passed to the inadyn service using LoadCredential.
        '';
        type = nullOr path;
      };
    };

  config = lib.mkIf cfg.enable {
    systemd.services.inadyn = {
      description = "Update nameservers using inadyn";
      requires = [ "network-online.target" ];
      startAt = cfg.interval;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''${pkgs.inadyn}/bin/inadyn -f ''${CREDENTIALS_DIRECTORY}/config --cache-dir /var/cache/inadyn -1 --foreground -l debug'';
        LoadCredential = "config:${configFile}";
        CacheDirectory = "inadyn";

        DynamicUser = true;
        UMask = "0177";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictAddressFamilies = "AF_INET AF_INET6";
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectSystem = "strict";
        ProtectProc = "invisible";
        ProtectHome = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallErrorNumber = "EPERM";
        SystemCallFilter = "@system-service";
        CapabilityBoundingSet = "";
      };
    };
  };
}
