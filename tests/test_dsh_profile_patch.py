"""Compile and exercise the package's replacement at both upstream call sites.

Uses installed tsc/node only; does not build DSH or access private inputs.
An optional package-expression path permits checking a previous patch version.
"""

from pathlib import Path
import re
import subprocess
import sys
from tempfile import TemporaryDirectory


FIXTURE = '''
let contents: string | undefined
let writes = 0
let reports = 0
const profile = { dir: "/profile" }
const PROFILE_ROOT_FILENAME = "cordis.yml"
const PROFILE_ROOT_CONFIG = "[]\\n"
function join(...parts: string[]): string { return parts.join("/") }
function existsSync(_path: string): boolean { return contents !== undefined }
function readFileSync(_path: string, _encoding: string): string {
  if (contents === undefined) throw new Error("read missing file")
  return contents
}
function writeFileSync(_path: string, value: string): void {
  writes += 1
  contents = value
}
function reportSkippedBundles(): void { reports += 1 }
function prepare(): void {
  reportSkippedBundles()
  writeFileSync(join(profile.dir, PROFILE_ROOT_FILENAME), PROFILE_ROOT_CONFIG)
}
function compose(resolvedProfile: object | undefined): void {
  if (resolvedProfile !== undefined) writeFileSync(join(profile.dir, PROFILE_ROOT_FILENAME), PROFILE_ROOT_CONFIG)
}
function verify(action: () => void, initial: string | undefined, expected: number): void {
  contents = initial
  writes = 0
  action()
  if (writes !== expected) throw new Error(`expected ${expected} writes, got ${writes}`)
  if (expected === 1 && contents !== PROFILE_ROOT_CONFIG) throw new Error("wrong root")
}
for (const action of [prepare, () => compose({})]) {
  verify(action, PROFILE_ROOT_CONFIG, 0)
  verify(action, undefined, 1)
  verify(action, "changed", 1)
}
verify(() => compose(undefined), undefined, 0)
verify(() => compose(undefined), "changed", 0)
if (reports !== 3) throw new Error("preceding call was lost")
'''


def main() -> None:
    package = (
        Path(sys.argv[1])
        if len(sys.argv) > 1
        else Path(__file__).resolve().parents[1] / "packages/dsh/default.nix"
    )
    expression = package.read_text().replace("\\\n", " ")
    replacements = re.findall(r"--replace-fail '([^']+)'\s+'([^']+)'", expression)
    matching = [(old, new) for old, new in replacements if old.startswith("writeFileSync(")]
    if len(matching) != 1:
        raise RuntimeError("expected exactly one profile-root replacement")
    old, new = matching[0]
    if FIXTURE.count(old) != 2:
        raise RuntimeError("fixture must cover both upstream write sites")
    with TemporaryDirectory(prefix="dsh-profile-patch-") as directory:
        source = Path(directory) / "fixture.ts"
        source.write_text(FIXTURE.replace(old, new))
        subprocess.run(
            ["tsc", "--strict", "--target", "ES2022", "--skipLibCheck", str(source)],
            check=True,
        )
        subprocess.run(["node", str(source.with_suffix(".js"))], check=True)
    print("Profile patch: TypeScript compilation and eight behavior cases passed")


if __name__ == "__main__":
    main()
