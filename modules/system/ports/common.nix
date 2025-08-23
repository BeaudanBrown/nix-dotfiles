{ lib, config, ... }:
let
  inherit (lib)
    mkOption
    types
    mapAttrsToList
    listToAttrs
    nameValuePair
    groupBy
    length
    foldl'
    head
    tail
    ;

  cfg = config.custom.ports;

  # Helpers to work with hex strings deterministically without external tools
  indexOf =
    xs: x:
    let
      go =
        i: ys:
        if ys == [ ] then
          null
        else if head ys == x then
          i
        else
          go (i + 1) (tail ys);
    in
    go 0 xs;

  hexDigitValue =
    c:
    let
      digits = lib.stringToCharacters "0123456789abcdef";
      idx = indexOf digits c;
    in
    if idx == null then 0 else idx;

  # Convert a sha256 hex (string) to a small integer using first 8 nybbles
  hexToNumber =
    s:
    let
      chars = lib.take 8 (lib.stringToCharacters s);
    in
    foldl' (acc: c: acc * 16 + hexDigitValue c) 0 chars;

  # Integer modulo implemented via doubling subtraction (no built-in mod)
  modInt =
    a: m:
    if m <= 0 then
      0
    else if a < m then
      a
    else
      (
        let
          largestMul = cur: if cur * 2 <= a then largestMul (cur * 2) else cur;
          d = largestMul m;
        in
        modInt (a - d) m
      );

  # Deterministic initial slot for a key within a range
  initialSlot =
    range: key:
    let
      space = range.end - range.start + 1;
      h = builtins.hashString "sha256" key; # lowercase hex
      n = hexToNumber h;
      idx = modInt n space;
    in
    range.start + idx;

  # Allocate ports for a list of records { key, rangeName, range }
  allocateForRange =
    {
      reserved,
      range,
      reqs,
    }:
    let
      # Create a set of used ports starting with reserved ones
      used0 = listToAttrs (map (p: nameValuePair (toString p) true) reserved);

      # Linear probing within [start, end]
      nextFree =
        used: port:
        if port > range.end then
          nextFree used range.start
        else if used ? ${toString port} then
          nextFree used (port + 1)
        else
          port;

      allocFold =
        acc: r:
        let
          startPort = initialSlot range r.key;
          chosen = nextFree acc.used startPort;
          used' = acc.used // {
            ${toString chosen} = true;
          };
        in
        {
          used = used';
          assignments = acc.assignments // {
            ${r.key} = chosen;
          };
        };

      result = foldl' allocFold {
        used = used0;
        assignments = { };
      } reqs;
    in
    result.assignments;

  # Resolve a request to an explicit range object and label
  resolveReq =
    r:
    let
      rangeName = if r.range == null then "__default__" else r.range;
      range = if rangeName == "__default__" then cfg.defaultRange else cfg.ranges.${rangeName};
    in
    r // { inherit rangeName range; };

  requests = map resolveReq cfg.requests;

  grouped = groupBy (r: r.rangeName) requests;

  # Allocate per range
  perRangeAssignments = mapAttrsToList (
    rangeName: reqs:
    let
      range = (lib.head reqs).range;
      reserved = cfg.reserved;
    in
    allocateForRange { inherit reserved range reqs; }
  ) grouped;

  mergedAssignments = builtins.foldl' (acc: asg: acc // asg) { } perRangeAssignments;

in
{
  options.custom.ports = {
    defaultRange = mkOption {
      type = types.submodule (
        { ... }:
        {
          options = {
            start = mkOption {
              type = types.int;
              default = 8100;
              description = "Start of default port range (inclusive).";
            };
            end = mkOption {
              type = types.int;
              default = 18999;
              description = "End of default port range (inclusive).";
            };
          };
        }
      );
      description = "Default port range used when no named range is specified.";
      default = { };
    };

    ranges = mkOption {
      type = types.attrsOf (
        types.submodule (
          { ... }:
          {
            options = {
              start = mkOption {
                type = types.int;
                description = "Start of named range (inclusive).";
              };
              end = mkOption {
                type = types.int;
                description = "End of named range (inclusive).";
              };
            };
          }
        )
      );
      default = { };
      description = "Named port ranges for grouping allocations (e.g., web, internal).";
    };

    reserved = mkOption {
      type = types.listOf types.int;
      default = [
        # DNS (CoreDNS / system resolvers)
        53

        # Standard HTTP/HTTPS served by nginx
        80
        443

        # Common alternative HTTP/HTTPS
        8080
        8443

        # Developer ports commonly in use; keep them free
        3000
        3001
        3002

        # Immich machine-learning service
        3003

        # Jitsi/Prosody HTTP endpoint
        5280

        # Authentik application (authentik-nix)
        9000
      ];
      description = "Ports to never allocate (global reserved list).";
    };

    requests = mkOption {
      type = types.listOf (
        types.submodule (
          { ... }:
          {
            options = {
              key = mkOption {
                type = types.str;
                description = "Unique service key, e.g., 'mealie' or 'pingvin/frontend'.";
              };
              range = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Optional named range to allocate from.";
              };
            };
          }
        )
      );
      default = [ ];
      description = "List of services requesting a unique port assignment.";
    };

    assigned = mkOption {
      type = types.attrsOf types.int;
      readOnly = true;
      description = "Computed mapping of request keys to assigned ports.";
    };
  };

  config = lib.mkIf (length requests > 0) {
    custom.ports.assigned = mergedAssignments;
  };
}
