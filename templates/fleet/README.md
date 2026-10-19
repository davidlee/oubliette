# A capsule fleet

This host's declarations for [oubliette](https://github.com/davidlee/oubliette):
which repos its capsules confine, which slots exist, what each slot may reach,
and what a fresh capsule is handed. `flake.nix` hands them to oubliette's
`lib.mkFleet`, which builds the guest images, the host programs, the devshell
and the host module. Each file is commented as the reference for its fields;
oubliette's README and `docs/` are the manual.

This copy confines one repo, [doctrine](https://github.com/davidlee/doctrine),
in one slot.

## First steps

1. **Create it.**

   ```sh
   mkdir fleet && cd fleet && git init
   nix flake init -t github:davidlee/oubliette
   ```

2. **Replace the stop key.** `keys/stop-key.pub` ships as a placeholder that
   nobody holds the private half of, and `just check` refuses it. The key is
   what a capsule's unit presents to stop its guest cleanly; generate it once
   per host, as oubliette's README ("Host requirements") describes, and commit
   only the public half:

   ```sh
   sudo install -d -m 0755 /var/lib/capsule-stop
   sudo ssh-keygen -t ed25519 -N "" -C "capsule stop key" -f /var/lib/capsule-stop/key
   sudo chown microvm:kvm /var/lib/capsule-stop/key && sudo chmod 0400 /var/lib/capsule-stop/key
   cp /var/lib/capsule-stop/key.pub keys/stop-key.pub
   ```

3. **Say where things are.** In `targets/doctrine.nix`, set `path` to your
   checkout of doctrine (the same repo as `inputs.doctrine` in `flake.nix`). In
   `flake.nix`, set `fleetPath` to this checkout's absolute path and `stateDir`
   to where this host keeps its state (`/var/lib/capsule` unless you have a
   reason; an absolute path over `[A-Za-z0-9._+/-]`, refused at eval otherwise),
   and put your own public key in `access.adminKeys` if you want to log into a
   guest as root — it is empty, so nobody can.

4. **Lock it** against published inputs only — never a `git+file` override,
   which writes a local path into the lock:

   ```sh
   nix flake lock
   ```

5. **Enter the devshell.** `.envrc` sets `CAPSULE_ROOT` and enters it; the
   devshell links `.oubliette` to oubliette's shared recipes. A global gitignore
   may ignore `.envrc`; this checkout's `.gitignore` re-includes it, so commit
   it.

   ```sh
   direnv allow      # or: nix develop
   ```

6. **Run the gate.** `just` checks these files, then builds every host program
   and suite against them and lists the host module's units.

   ```sh
   just
   ```

Nothing above boots a capsule. Starting one, the host module, and the host's
own NixOS config are oubliette's README.

## What this template is checked for, and what not

Oubliette evaluates this `flake.nix` against stub inputs on every build of its
own (`templateCases`), so a template that no longer fits `mkFleet` fails there.
That proves the declarations *evaluate*. It does not lock or build them against
the real doctrine flake, boot a guest, or run this `justfile`, `.envrc` or the
steps above.
