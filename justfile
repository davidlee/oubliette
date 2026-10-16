# capsule — firecracker agent jail. README.md is usage, docs/ is everything else.
#
# The shared recipes (build, units, cases, verify and every operational one)
# live in just/fleet.just, imported below; a consumer imports the same file
# through `.oubliette`. What stays here is oubliette's own development gate.

# Every nix file that is ours. Explicit, so nothing walks .direnv or .vm.
nix_paths := "flake.nix mkfleet.nix fleet.nix fleet-cases.nix net.nix targets capsules.nix host-capsules.nix policies.nix fragments.nix setup.nix perimeter host vm"

# the gate: everything parses and is formatted
default: check build units
import 'just/fleet.just'

# parse + format, no eval and no build: cheap enough for every edit
check: parse fmt-check

# every nix file parses — and `--parse` never evaluates, so it cannot build
parse:
  #!/usr/bin/env bash
  set -euo pipefail
  find {{nix_paths}} -name '*.nix' -print0 | xargs -0 -n1 nix-instantiate --parse >/dev/null
  echo "parse: ok"

# format
fmt:
  alejandra -q {{nix_paths}}

# assert formatting without mutating it
fmt-check:
  alejandra -c {{nix_paths}}

# update & switch the system nix derivation
update-system:
  cd ~/flakes && just update-local && just system-switch
