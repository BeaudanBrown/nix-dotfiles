{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenv,
}:
let
  version = "0.1.1";
  runtime = fetchurl {
    url = "https://github.com/moonshine-ai/moonshine/releases/download/v${version}/moonshine-voice-linux-x86_64.tar.gz";
    hash = "sha256-+VuF7OqMTHRn0gq+bP+1xcRuv7uN4mDDOjkA06vKJTU=";
  };
  modelFiles = {
    "adapter.ort" = fetchurl {
      url = "https://download.moonshine.ai/model/small-streaming-en/quantized_26_07_30/adapter.ort";
      hash = "sha256-xmX3QjZP661ZfMmsHgs0H/vuDiShRm4vO96V5uR3F2I=";
    };
    "cross_kv.ort" = fetchurl {
      url = "https://download.moonshine.ai/model/small-streaming-en/quantized_26_07_30/cross_kv.ort";
      hash = "sha256-4tNBcUTpUUBV6/7+jcxMClWlWty4UwQ1hEx1xT41K/Y=";
    };
    "decoder_kv.ort" = fetchurl {
      url = "https://download.moonshine.ai/model/small-streaming-en/quantized_26_07_30/decoder_kv.ort";
      hash = "sha256-GgVGWx3ZVYWN/L7gOcACD7XdmCsPUJTDTmFzXVGNdxs=";
    };
    "encoder.ort" = fetchurl {
      url = "https://download.moonshine.ai/model/small-streaming-en/quantized_26_07_30/encoder.ort";
      hash = "sha256-LU2XPpHorKCMUefn76KKRqsmW2PYCdUpTRi4a82FuZM=";
    };
    "frontend.ort" = fetchurl {
      url = "https://download.moonshine.ai/model/small-streaming-en/quantized_26_07_30/frontend.ort";
      hash = "sha256-0b6BRbye8+hiW7e8t6Wykw7rgoyR1sGJe8IV195vK5M=";
    };
    "streaming_config.json" = fetchurl {
      url = "https://download.moonshine.ai/model/small-streaming-en/quantized_26_07_30/streaming_config.json";
      hash = "sha256-JvAravsi1ghxpe/YXD045WnMDdtsXrbpPTJgFSropHo=";
    };
    "tokenizer.bin" = fetchurl {
      url = "https://download.moonshine.ai/model/small-streaming-en/quantized_26_07_30/tokenizer.bin";
      hash = "sha256-aISzX9Y3fUxNMjNqC8FS82tk0eRbZQNoPNwjglCoRy0=";
    };
  };
in
assert lib.assertMsg stdenv.hostPlatform.isx86_64
  "moonshine-stt currently supports x86_64-linux work hosts only";
stdenv.mkDerivation {
  pname = "moonshine-stt";
  inherit version;
  src = runtime;

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  buildPhase = ''
    runHook preBuild
    $CXX -std=c++17 -O2 -Wall -Wextra \
      -Iinclude \
      ${./daemon.cpp} \
      -Llib -lmoonshine \
      -Wl,-rpath,'$ORIGIN/../lib/moonshine-stt' \
      -o moonshine-stt-daemon
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 moonshine-stt-daemon $out/bin/moonshine-stt-daemon
    install -Dm755 lib/libmoonshine.so $out/lib/moonshine-stt/libmoonshine.so
    install -Dm755 lib/libonnxruntime.so.1 $out/lib/moonshine-stt/libonnxruntime.so.1
    mkdir -p $out/share/moonshine-stt/small-streaming-en
    ${lib.concatMapStringsSep "\n" (
      name: "cp ${modelFiles.${name}} $out/share/moonshine-stt/small-streaming-en/${name}"
    ) (builtins.attrNames modelFiles)}
    runHook postInstall
  '';

  meta = {
    description = "Local Moonshine Small Streaming speech-to-text daemon";
    homepage = "https://github.com/moonshine-ai/moonshine";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "moonshine-stt-daemon";
  };
}
