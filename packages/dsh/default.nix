{ dsh }:
# Upstream 0.2.2-rc.1 rewrites an identical empty profile root on every boot.
# Avoid that write only when bytes already match, allowing a Nix-owned profile.
# A missing/changed root still follows upstream's write/failure behavior.
dsh.overrideAttrs (old: {
  postPatch = (old.postPatch or "") + ''
    substituteInPlace apps/cli/src/profile-boot.ts \
      --replace-fail 'existsSync, mkdirSync,' 'existsSync, readFileSync, mkdirSync,' \
      --replace-fail 'writeFileSync(join(profile.dir, PROFILE_ROOT_FILENAME), PROFILE_ROOT_CONFIG)' \
        '((existsSync(join(profile.dir, PROFILE_ROOT_FILENAME)) && readFileSync(join(profile.dir, PROFILE_ROOT_FILENAME), "utf8") === PROFILE_ROOT_CONFIG) || writeFileSync(join(profile.dir, PROFILE_ROOT_FILENAME), PROFILE_ROOT_CONFIG))'
  '';
  meta = old.meta // {
    description = "${old.meta.description} (immutable-profile compatibility)";
  };
})
