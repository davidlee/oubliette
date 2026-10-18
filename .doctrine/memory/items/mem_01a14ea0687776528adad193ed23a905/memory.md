A probe built straight from the consumer (`nix build /srv/fleet#probe-netns-boot`)
uses the **consumer's own nixpkgs lock**. The installed system does not:
`~/flakes` makes `fleet` follow its nixpkgs. When the consumer's pin lags the
system's, the probe's `runuser` (from `util-linux`, linked to the older glibc)
dlopens the **host's** PAM modules from `/etc/pam.d/runuser` (built against the
newer glibc), cannot load them, and PAM reports it as:

    runuser: cannot open session: Module is unknown

at the harness's first `as_human`/`runuser` step ("building the runner (as
david)"). Seen 2026-10-18 at SL-005 PHASE-09: consumer nixpkgs `e94cb15`
(glibc 2.42) vs system `7fd4004` (glibc 2.44). Nothing is wrong with PAM — the
modules all exist.

Fix: keep the consumer's nixpkgs at the system's (`nix flake update nixpkgs` in
`/srv/fleet`, commit, push). One-off: build with `--override-input nixpkgs
github:NixOS/nixpkgs/<rev from ~/flakes/flake.lock>`.

Related, same run: a probe's ssh-identity refusal (`human_ssh_identity`) comes
**before** its running-VM refusal, so `sudo probe-…` without
`CAPSULE_SSH_KEY=$HOME/.ssh/id` refuses for a reason that is not the one under
test (see `fact.oubliette.sudo-strips-ssh-auth-sock`). Related:
[[fact.oubliette.flakes-builds-this-repo-two-ways]].
