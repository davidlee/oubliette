# The fragment vocabulary — what a guest may be composed out of, and the only
# place a tool that belongs to no project is allowed to be named.
#
# [docs/contract-flavour.md](./docs/contract-flavour.md) is the design and this
# is its build-time half: a flavour is `compose(floor, extras)`, the **floor** is
# the project's (its target's `toolsPackage` and `extraTools`, threaded through
# `vm/capsule.nix` as it always was) and the **extras** are the host operator's,
# drawn from a vocabulary the host declares. This file is that vocabulary;
# the caller's `flavour.extras` is the selection. Neither owner can quietly become the
# other, which is the whole reason the two lists are separate files.
#
# Three rules it exists to keep, all of them the contract's:
#
#   - **Convenience is declared, never inherited.** A fragment that copied this
#     human's dotfiles would describe a machine the capsule is not, and would be
#     a channel for host state into a confinement whose claim is that no host
#     directory gets in. Everything below is spelled out here or it does not
#     exist in the guest.
#   - **A fragment source is a flake input of this repo**, pinned in a lock this
#     host owns, so adding a tool source is a deliberate act with a rebuild
#     behind it (NOTES item 26).
#   - **A tool that is target-shaped does not come here.** The smell is the same
#     one CLAUDE.md names: a toolchain's name outside `targets/`. `rg` and
#     `tmux` are nobody's project, which is exactly why a target's file is the
#     wrong home for them.
#
# An entry is `{packages = …;}`, and may carry two more keys, for rooms
# (SL-009 design sec-2): `guestModule`, a NixOS module the room imports, and
# `persist`, the absolute paths that must survive the guest's lifecycle. A slot
# refuses both (`slotRefusal`, design sec-5): where a slot would persist is its
# own design. `programs.nix-ld` is still not one of these — every
# non-nix-native toolchain needs it, so it belongs in what the capsule
# *supplies* (NOTES item 23).
#
# One thing deliberately absent, so it does not read as an oversight:
#
#   - **Per-slot selection.** `extras` is one list for the fleet, so every slot
#     arrives at one composition and the one-image lever is untouched (NOTES
#     item 21). Selection per assignment — and with it the record's `image`, the
#     gcroot that retains it, and the refusal to change a composition under a
#     dirty volume — is Plan D D7. This file is what that would select *from*.
#     A room is the exception, because it is its own image: it selects its own
#     list (`rooms.<r>.extras`) into its base (DEC-052).
{
  pkgs,
  # The flake inputs a fragment is built from (mkFleet's `flavour.sources`):
  # the host's tool sources, never the whole of anyone's `inputs`.
  sources,
  # A room imports `modules`, and an `imports` list is read before `config`, so
  # it may not force the guest's `pkgs` (which is `config._module.args`).
  # `vm/room.nix` hands its own module `lib`; every other caller takes the default.
  lib ? pkgs.lib,
}: let
  inherit (pkgs.stdenv.hostPlatform) system;

  # The agent CLIs, from llm-agents rather than from nixpkgs. Same derivations
  # `~/flakes/pub`'s `unjailed` exports — that attrset is `inherit
  # (llm-agents.packages.${system}) claude-code pi` and nothing else — so this
  # is one input where going through pub would have been five, for the same
  # store paths. `codex` is not in pub's set; it is here because a goad kit walk
  # loads its plugin into both agents (goad slice 012 PHASE-11, EN-4). It supersedes `pkgs.claude-code` and the `allowUnfreePredicate`
  # that named it: the derivation is created in llm-agents' own eval, so this
  # repo's nixpkgs config no longer gates it (NOTES item 3).
  #
  # The jailed wrappers stay out, as they always have: they bind *host* paths
  # this guest does not have, and the capsule's confinement is the VM.
  llm = sources.llm-agents.packages.${system};

  # Name -> fragment. Small on purpose: a fragment used by one slot is its own
  # 3.0 GiB image, so broad-and-few is arithmetic rather than taste
  # (docs/contract-flavour.md, docs/probes.md). That arithmetic is slot-grain: a
  # room is its own image already, so a fragment only rooms select costs only
  # their images (DEC-052).
  vocabulary = {
    # What makes the capsule a place an agent can work at all. `bubblewrap`
    # because an agent that jails its own subprocesses needs one in the guest —
    # the guest's, over guest paths, which is a different thing from the host
    # wrappers above.
    agents = {
      packages =
        [llm.claude-code llm.codex llm.pi]
        ++ (with pkgs; [ripgrep fd tree jq bubblewrap]);
    };

    # What makes it a place a human can look around in. `helix` rather than
    # neovim for the reason the convenience rule forces: a guest has no dotfiles
    # and may never be given this host's, so an editor that is useful unconfigured
    # is the one that survives the rule.
    dev-facilities = {
      packages = with pkgs; [helix tmux btop nushell];
    };

    # Room-grain, finer than a slot would want, since a room is its own image
    # (DEC-052): search without the agents, and an editor of a person's choosing.
    search = {
      packages = with pkgs; [ripgrep fd];
    };
    emacs = {
      packages = [pkgs.emacs];
    };

    # A capability fragment, for rooms: a guest module and the paths that must
    # survive. SL-009 design sec-4 (DEC-062, DEC-063, DEC-065, DEC-067) is the
    # contract and this entry is transcribed from it; slots refuse it (sec-5).
    postgresql-18 = {
      packages = [];
      persist = ["/var/lib/postgresql"];
      guestModule = {
        config,
        lib,
        pkgs,
        ...
      }: let
        logins = lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);
        # Names PostgreSQL refuses as roles, its superuser, and the databases a
        # fresh cluster already has, which ensureDBOwnership would hand over.
        # `shared_` is the operator's, for shared roles (below).
        reserved = n:
          lib.hasPrefix "pg_" n
          || lib.hasPrefix "shared_" n
          || builtins.elem n ["postgres" "public" "none" "current_user" "current_role" "session_user" "template0" "template1"];
      in {
        assertions = [
          {
            assertion = !(lib.any reserved logins);
            message = "fragments.nix postgresql-18: a login is a reserved role name: ${toString (lib.filter reserved logins)}";
          }
        ];
        services.postgresql = {
          enable = true;
          package = pkgs.postgresql_18;
          enableTCPIP = false;
          settings.listen_addresses = lib.mkForce "";
          # Replaces NixOS's default rules, whose `local all all peer` would admit
          # any login to any database. NixOS adds those with mkAfter, so a
          # prepended rule would leave them as the fallback.
          authentication = lib.mkForce ''
            local all      postgres peer map=postgres
            local samerole all      peer
          '';
          ensureDatabases = logins;
          ensureUsers =
            map (name: {
              inherit name;
              ensureDBOwnership = true;
            })
            logins;
        };
      };
    };
  };

  known = lib.concatStringsSep ", " (builtins.attrNames vocabulary);

  # One lookup, so every selection function refuses an unknown name alike. It
  # reads a *selected* name only, so an unselected entry's module is never forced.
  entry = name:
    vocabulary.${name}
    or (throw "fragments.nix: no fragment named '${name}' — the vocabulary is ${known}");

  hasPersist = name: (entry name).persist or [] != [];
  isCapability = name: (entry name) ? guestModule || hasPersist name;
in {
  inherit vocabulary;

  # `compose(floor, extras)`. Ordered for legibility only — nothing depends on
  # where in the list a fragment sits — and collisions are left to nix, which
  # fails the build rather than silently shadowing a toolchain. That failure is
  # the wanted behaviour, and `lib.hiPrio` at the call site is its deliberate
  # override.
  #
  # An unknown name is refused rather than resolving to nothing, because a
  # fragment that silently does not exist is a guest quietly missing its tools.
  compose = {
    floor,
    extras,
  }:
    floor ++ lib.concatMap (name: (entry name).packages) extras;

  # The selected entries' guest modules, unparameterised (a room imports them).
  modules = extras: lib.concatMap (name: lib.optional (entry name ? guestModule) (entry name).guestModule) extras;

  # What the selection needs to survive its guest's lifecycle, one per path.
  persists = extras:
    lib.concatMap (name:
      map (path: {inherit name path;}) ((entry name).persist or []))
    extras;

  # Why a slot cannot take this selection, or null. A slot's volume is its
  # checkout and a provision resets it, so where a capability would persist is
  # its own design; `vm/capsule.nix` turns this into an assertion (design sec-5).
  slotRefusal = extras: let
    names = lib.filter isCapability extras;
  in
    if names == []
    then null
    else "a capsule image cannot select capability fragments ${lib.concatStringsSep ", " names}: a slot's volume is its checkout and a provision resets it, so where it would persist is its own design (SL-009 DEC-060, NOTES item 4)";
}
