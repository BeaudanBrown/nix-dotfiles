# Generator for .sops.yaml based on centralized hostSpecs
{ lib }:
let
  allHostsData = import ../modules/host-spec/all-hosts.nix;
  hostSpecs = allHostsData.hostSpecs;
  masterKey = allHostsData.masterKey;

  # Helper to get valid user keys from a host spec
  getValidUsers =
    spec:
    if builtins.hasAttr "users" spec then builtins.filter (u: u.ageUserKey != null) spec.users else [ ];

  # Always include NAS host/user keys as a "live" admin decryptor for every file.
  # Master key remains a backup failsafe.
  nasRecipients =
    if builtins.hasAttr "nas" hostSpecs then
      let
        spec = hostSpecs.nas;
        hostKey = if spec.ageHostKey != null then [ "nas" ] else [ ];
        userKeys = map (u: "${u.username}_nas") (getValidUsers spec);
      in
      hostKey ++ userKeys
    else
      [ ];

  # Extract all unique roots across all hosts
  allRoots = hostSpecs |> lib.mapAttrsToList (_: spec: spec.roots) |> lib.flatten |> lib.unique;

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
      userKeys = map (u: {
        anchor = "${u.username}_${hostname}";
        key = u.ageUserKey;
      }) (getValidUsers spec);
    in
    hostKey ++ userKeys;

  # All keys with anchors (including master key)
  allKeys = [
    {
      anchor = "master";
      key = masterKey;
    }
  ]
  ++ (hostSpecs |> lib.mapAttrsToList keysForHost |> lib.flatten);

  # Filter out null keys
  validKeys = allKeys |> builtins.filter (k: k.key != null);

  # Get recipient anchors for hosts with a specific root
  # Only include hosts that have at least one valid key
  getRecipientsForRoot =
    root:
    let
      recipients =
        hostSpecs
        |> lib.mapAttrsToList (
          hostname: spec:
          if builtins.elem root spec.roots then
            (
              (if spec.ageHostKey != null then [ hostname ] else [ ])
              ++ (map (u: "${u.username}_${hostname}") (getValidUsers spec))
            )
          else
            [ ]
        )
        |> lib.flatten;
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
        ++ (map (u: "${u.username}_${hostname}") (getValidUsers spec));
    in
    # Always include master key and NAS keys, plus host-specific keys
    lib.unique ([ "master" ] ++ nasRecipients ++ hostRecipients);

  # Check if a host has any valid keys
  hostHasKeys =
    hostname:
    let
      spec = hostSpecs.${hostname};
    in
    (spec.ageHostKey != null) || ((builtins.length (getValidUsers spec)) > 0);

  # Check if a root has any hosts with valid keys
  rootHasKeys =
    root:
    let
      hostsWithRoot =
        hostSpecs |> lib.attrNames |> lib.filter (hostname: builtins.elem root hostSpecs.${hostname}.roots);
      hostsWithKeys = hostsWithRoot |> lib.filter hostHasKeys;
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
  hostsWithKeys = hostSpecs |> lib.attrNames |> lib.filter hostHasKeys;
  rootsWithKeys = allRoots |> lib.filter rootHasKeys;

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
