# A goad kit walk. The capsule clones this repo, not goad's, so a walking agent
# sees the kit and the binaries and nothing else of goad (goad docs/slices/012).
#
# Every absent path is spelled as a value: `vm/capsule.nix` reads these fields
# without an `or`. What each field means is targets/doctrine.nix's commentary,
# and docs/contract-target.md is the contract.
{
  path = "/home/david/dev/goad-walk";
  toolsPackage = "default"; # goad, goad-emit, ruby, jq (+ goad-check, goad-kit)
  extraTools = [];
  caches = {};
  guestConfig = {};
  commands = "";
  baseline = null;
  refresh = null;
  # statePaths, stateMaxBytes: omitted — no out-of-band state (profile.nix `or`).

  # Chosen for goad-walk, not copied from doctrine (NOTES item 23): a stdlib
  # ruby script and its harness need neither cargo's memory nor its volume. A
  # starting point, not a measurement; the first real walk checks them.
  # `volume` is fixed at a volume's first boot.
  sizes = {
    vcpu = 2;
    mem = 2048;
    volume = 8192;
  };
}
