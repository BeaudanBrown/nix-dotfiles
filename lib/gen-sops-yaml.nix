# Generator for .sops.yaml based on centralized hostSpecs
{ lib }:
let
  allHostsData = import ../modules/host-spec/all-hosts.nix;
  hostSpecs = allHostsData.hostSpecs;
  masterKey = allHostsData.masterKey;

  # Always include NAS host/user keys as a "live" admin decryptor for every file.
  # Master key remains a backup failsafe.
  nasRecipients =
    if builtins.hasAttr "nas" hostSpecs then
      let
        spec = hostSpecs.nas;
      in
      (if spec.ageHostKey != null then [ "nas" ] else [ ])
      ++ (if spec.ageUserKey != null then [ "${spec.username}_nas" ] else [ ])
    else
      [ ];

  # Extract all unique roots across all hosts
  allRoots = lib.unique (lib.flatten (lib.mapAttrsToList (_: spec: spec.roots) hostSpecs));

  # Build keys list with anchors for YAML
  # Format: { anchor = "hostname"; key = "age1..."; }
  keysForHost =
    hostname: spec:
    let
      hostKey =
        if spec.ageHostKey != null then
          [
            {
              anchor = hostname;
              key = spec.ageHostKey;
            }
          ]
        else
          [ ];
      userKey =
        if spec.ageUserKey != null then
          [
            {
              anchor = "${spec.username}_${hostname}";
              key = spec.ageUserKey;
            }
          ]
        else
          [ ];
    in
    hostKey ++ userKey;

  # All keys with anchors (including master key)
  allKeys = [
    {
      anchor = "master";
      key = masterKey;
    }
  ]
  ++ (lib.flatten (lib.mapAttrsToList keysForHost hostSpecs));

  # Filter out null keys
  validKeys = builtins.filter (k: k.key != null) allKeys;

  # Get recipient anchors for hosts with a specific root
  # Only include hosts that have at least one valid key
  getRecipientsForRoot =
    root:
    let
      recipients = lib.flatten (
        lib.mapAttrsToList (
          hostname: spec:
          if builtins.elem root spec.roots then
            (
              (if spec.ageHostKey != null then [ hostname ] else [ ])
              ++ (if spec.ageUserKey != null then [ "${spec.username}_${hostname}" ] else [ ])
            )
          else
            [ ]
        ) hostSpecs
      );
    in
    # Always include master key and NAS keys, plus any root-scoped keys
    lib.unique ([ "master" ] ++ nasRecipients ++ recipients);

  # Get recipient anchors for a specific host
  getRecipientsForHost =
    hostname:
    let
      spec = hostSpecs.${hostname};
      hostRecipients =
        (if spec.ageHostKey != null then [ hostname ] else [ ])
        ++ (if spec.ageUserKey != null then [ "${spec.username}_${hostname}" ] else [ ]);
    in
    # Always include master key and NAS keys, plus host-specific keys
    lib.unique ([ "master" ] ++ nasRecipients ++ hostRecipients);

  # Check if a host has any valid keys
  hostHasKeys =
    hostname:
    let
      spec = hostSpecs.${hostname};
    in
    (spec.ageHostKey != null) || (spec.ageUserKey != null);

  # Check if a root has any hosts with valid keys
  rootHasKeys =
    root:
    let
      hostsWithRoot = lib.filter (hostname: builtins.elem root hostSpecs.${hostname}.roots) (
        lib.attrNames hostSpecs
      );
      hostsWithKeys = lib.filter hostHasKeys hostsWithRoot;
    in
    (builtins.length hostsWithKeys) > 0;

  # Generate creation rule for a host secrets file (only if host has keys)
  hostRule = hostname: {
    path_regex = "secrets/${hostname}\\.yaml$";
    key_groups = [
      {
        age = getRecipientsForHost hostname;
      }
    ];
  };

  # Generate creation rule for a root secrets file (only if root has hosts with keys)
  rootRule = root: {
    path_regex = "secrets/${root}\\.yaml$";
    key_groups = [
      {
        age = getRecipientsForRoot root;
      }
    ];
  };

  # Filter hosts and roots to only those with valid keys
  hostsWithKeys = lib.filter hostHasKeys (lib.attrNames hostSpecs);
  rootsWithKeys = lib.filter rootHasKeys allRoots;

  # All host rules (only for hosts with keys)
  hostRules = map hostRule hostsWithKeys;

  # All root rules (only for roots with hosts that have keys)
  rootRules = map rootRule rootsWithKeys;

  # Complete .sops.yaml structure
  sopsConfig = {
    keys = map (k: { "${k.anchor}" = k.key; }) validKeys;
    creation_rules = hostRules ++ rootRules;
  };
in
sopsConfig
