{ pkgs, dsh }:
let
  src = pkgs.fetchFromGitHub {
    owner = "kfc966";
    repo = "dsh-native-codex-oauth";
    rev = "28273cc4615f2e4cb5a11cf0c57968b68101f737";
    hash = "sha256-NqW48eFlqoV0XGaYZSBeuApLe8fqft7nqAYPyvppCxY=";
  };
in
pkgs.runCommand "dsh-native-codex-oauth" { } ''
  mkdir -p "$out"
  cp -r ${src}/{lib,package.json,LICENSE} "$out/"
  chmod -R u+w "$out/lib"
  # The alpha plugin shipped eager Zod codecs; rc.4 requires create() on
  # host AND browser Remote descriptors. Preserve each original validator.
  for f in "$out/lib/"{typert,remote,client}.js; do
    test "$(grep -c 'schema: _deepseek_ai_' "$f")" = 15
    sed -i -E 's/schema: (_deepseek_ai_[[:alnum:]_$]+)/create: () => \1/g' "$f"
  done
  # Resolve peers against the very same Cordis/Typert installation as DSH.
  ln -s ${dsh}/lib/node_modules/@deepseek-ai/dsh/node_modules "$out/node_modules"
''
