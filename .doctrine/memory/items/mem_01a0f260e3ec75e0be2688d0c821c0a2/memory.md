`/var/lib/microvms/<slot>/booted` is written by microvm.nix's
`microvm-set-booted@<slot>` (`ln -s "$(readlink current)" booted`, ordered
before `microvm@<slot>`) and removed by its `ExecStop`. So it exists **exactly
while the VM is up** and names the runner actually running. `current` is what
`microvm -u` / `install-microvm-<slot>` last wrote, which may be newer.

The runner's `bin/microvm-run` ends in
`exec -a "microvm@<hostName>" …/firecracker --config-file /nix/store/…-firecracker-<hostName>.json`.
That JSON's `."boot-source".boot_args` is `console=… ${microvm.kernelParams}`.

`microvm.kernelParams` includes `boot.kernelParams` but is **not** in the
guest's toplevel (options.nix:586). So a parameter added there changes only the
runner's config, not the guest system. SL-003 uses this for the
`capsule.target=<name>` marker (DEC-021) that `bootedTarget` in host/cli.nix
reads.

Observed on slot c, 2026-09-30: an unmarked runner's only identifying datum is
the `init=` store path.
