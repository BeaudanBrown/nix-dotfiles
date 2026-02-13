{
  config,
  pkgsUnstable,
  ...
}:
let
  domain = "pdf.bepis.lol";
  portKey = "docling";
in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      inherit domain;
      upstreamHost = config.services.docling-serve.host;
      upstreamPort = toString config.services.docling-serve.port;
    }
  ];

  nixpkgs.config.allowBroken = true;

  # nixpkgs.overlays = [
  #   (final: prev: {
  #     docling = prev.docling.overrideAttrs (oldAttrs: rec {
  #       version = "2.67.0";
  #       src = prev.fetchFromGitHub {
  #         owner = "docling-project";
  #         repo = "docling";
  #         tag = "v${version}";
  #         hash = "sha256-2UZTD1YV5/sDKkMA6ISZ0BXv6jsTBSoQGrCvnN0aGwk=";
  #       };

  #       # 1. Add CMake to nativeBuildInputs if not already present (needed for the build step)
  #       nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [
  #         final.cmake
  #         final.pkg-config
  #         final.python3Packages.pythonRelaxDepsHook # Keep this from previous fix
  #       ];

  #       # 2. Add C++ dependencies to buildInputs
  #       # Docling compilation often requires these libs.
  #       # Note: If 'tabula-py' or similar is involved, java might be needed, but usually it's just these:
  #       buildInputs = (oldAttrs.buildInputs or []) ++ [
  #         final.libpng
  #         final.zlib
  #         final.libjpeg
  #       ];

  #       # 3. Disable the C++ build isolation if it's trying to download deps
  #       # Many python packages with C++ extensions try to use 'conan' or fetch deps online.
  #       # We set an env var to tell it to look for system libs.
  #       env = (oldAttrs.env or {}) // {
  #         DOCLING_BUILD_WITH_SYSTEM_LIBS = "1";
  #       };

  #       # 4. If the error persists, you might need to disable the C++ extension build
  #       # if you only need the python logic, though this might break functionality.
  #       # DOCLING_DISABLE_CPP_BUILD = "1";

  #       pythonRelaxDeps = [ "pillow" "jsonlines" ];
  #     });

  #     # Keep the docling-ibm-models override from the previous step if you still need it
  #     pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
  #       (python-final: python-prev: {
  #         docling-ibm-models = python-prev.docling-ibm-models.overridePythonAttrs (old: {
  #           nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
  #             python-final.pythonRelaxDepsHook
  #           ];
  #           pythonRelaxDeps = [ "pillow" "jsonlines" ];
  #         });
  #       })
  #     ];
  #   })
  # ];

  # nixpkgs.overlays = [
  #   (final: prev: {
  #     docling = prev.docling.overrideAttrs (oldAttrs: rec {
  #       version = "2.67.0";
  #       src = prev.fetchFromGitHub {
  #         owner = "docling-project";
  #         repo = "docling";
  #         tag = "v${version}";
  #         hash = "sha256-2UZTD1YV5/sDKkMA6ISZ0BXv6jsTBSoQGrCvnN0aGwk=";
  #       };
  #     });

  #     # 2. We inject the fix into the Python environment
  #     pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
  #       (python-final: python-prev: {
  #         docling-ibm-models = python-prev.docling-ibm-models.overridePythonAttrs (old: {
  #           # This hook allows us to ignore specific version constraints
  #           nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
  #             final.cmake
  #             final.pkg-config
  #             python-final.pythonRelaxDepsHook
  #           ];
  #           # Tell the hook to remove the version cap on pillow
  #           pythonRelaxDeps = [ "pillow" "jsonlines" ];
  #         });
  #       })
  #     ];
  #   })
  # ];

  # environment.systemPackages = [
  #   pkgs.docling
  # ];

  services.docling-serve = {
    enable = false;
    package = pkgsUnstable.docling-serve.override {
      withUI = true;
      withTesserocr = true;
      withCPU = true;
      withRapidocr = true;
    };
    port = config.custom.ports.assigned.${portKey};
    environment = {
      DOCLING_SERVE_ENABLE_UI = "True";
      # Disable Gradio telemetry and ensure single-process state consistency
      GRADIO_ANALYTICS_ENABLED = "False";
      UVICORN_WORKERS = "1";
    };
  };
}
