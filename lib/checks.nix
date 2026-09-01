{
  inputs,
  pkgs,
  system,
  ...
}:
let
  dashboardDefinitions = import ../modules/services/grafana/dashboards.nix;
  dashboardsJson = pkgs.writeText "bepis-grafana-dashboards.json" (
    builtins.toJSON dashboardDefinitions
  );
in
{
  bepis-grafana-dashboard-contract =
    pkgs.runCommand "bepis-grafana-dashboard-contract"
      {
        nativeBuildInputs = [ pkgs.jq ];
      }
      ''
        jq --exit-status '
          length == 5
          and ([.[].uid] | unique | length == 5)
          and all(.[];
            .editable == false
            and .schemaVersion >= 41
            and (.tags | index("bepis") != null)
            and (.tags | index("observability") != null)
          )
          and ([.[].uid] | sort == [
            "bepis-diagnostic-profiles",
            "bepis-production-logs",
            "bepis-request-traces",
            "bepis-roster-hot-paths",
            "bepis-runtime-boundaries"
          ])
          and all(
            [.[] | select(.uid != "bepis-production-logs") | .panels[].targets[]?][];
            .datasource.uid == "$tempo"
            and .queryType == "traceql"
          )
          and all(
            [.[] | .panels[].targets[]? | (.query // .expr // "")][];
            (test("email|customer|credential|https?://"; "i") | not)
          )
        ' ${dashboardsJson}
        touch "$out"
      '';

  pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
    src = ./.;
    default_stages = [ "pre-commit" ];
    hooks = {
      # ========== General ==========
      check-added-large-files = {
        enable = true;
        excludes = [
          "\\.png"
          "\\.jpg"
        ];
      };
      check-case-conflicts.enable = true;
      check-executables-have-shebangs.enable = true;
      check-shebang-scripts-are-executable.enable = false;
      check-merge-conflicts.enable = true;
      detect-private-keys.enable = true;
      fix-byte-order-marker.enable = true;
      mixed-line-endings.enable = true;
      trim-trailing-whitespace.enable = true;

      forbid-submodules = {
        enable = true;
        name = "forbid submodules";
        description = "forbids any submodules in the repository";
        language = "fail";
        entry = "submodules are not allowed in this repository:";
        types = [ "directory" ];
      };

      destroyed-symlinks = {
        enable = true;
        name = "destroyed-symlinks";
        description = "detects symlinks which are changed to regular files with a content of a path which that symlink was pointing to.";
        package = inputs.pre-commit-hooks.packages.${system}.pre-commit-hooks;
        entry = "${inputs.pre-commit-hooks.packages.${system}.pre-commit-hooks}/bin/destroyed-symlinks";
        types = [ "symlink" ];
      };

      # ========== nix ==========
      nixfmt-rfc-style.enable = true;
      deadnix = {
        enable = true;
        settings = {
          noLambdaArg = true;
        };
      };

      # ========== shellscripts ==========
      shfmt.enable = true;
      shellcheck = {
        enable = true;
        files = ".*\.sh$";
      };

      end-of-file-fixer.enable = true;
    };
  };
}
