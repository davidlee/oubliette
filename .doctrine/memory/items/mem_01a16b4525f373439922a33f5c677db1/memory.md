Three found designing SL-009 (RV-025), each in the pinned nixpkgs:

- **postgresql `ProtectHome = true`** (nixos/modules/services/databases/postgresql.nix ~809): a `dataDir` on `/home` is invisible to the unit. Keep the default dataDir and bind-mount persistent storage onto `/var/lib/postgresql` instead (DEC-061). A bind `fileSystems` entry also needs `fsType = "none"` — it has no default.
- **pg_hba defaults are `mkAfter`** (same file ~688): adding a rule prepends it, and NixOS's `local all all peer` still matches as fallback. Replace with `lib.mkForce` (DEC-063). `postgresql.service` active does not mean roles exist; `postgresql.target` requires `postgresql-setup` too.
- **sudo enabled ⇒ default root and wheel `extraRules`, and terminfo `extraConfig`** (security/sudo.nix ~219-260, config/terminfo.nix ~89-100): a guard asserting them empty fails a clean guest. Disable sudo and assert the effective `enable` of sudo, sudo-rs and doas instead (DEC-060).

General shape: check the merged, effective option value in the pinned source before writing a predicate over it.
