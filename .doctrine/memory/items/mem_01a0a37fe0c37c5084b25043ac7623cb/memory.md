Checked 2026-09-15:

- `openssh-10.5p1/session.c:1502`: "When PAM is enabled we rely on it to do the
  nologin check", and `do_nologin` runs only when PAM is off.
- NixOS's sshd module defaults `UsePAM` to true; the guest's
  `/etc/ssh/sshd_config` says `UsePAM yes` (slot `b`).
- No NixOS PAM stack carries `pam_nologin` except some display managers'. The
  guest's `/etc/pam.d/sshd` has none, and neither does any file in this host's
  `/etc/pam.d/`.

So `/etc/nologin` (or `/run/nologin`, which `systemd-user-sessions` writes) blocks
nothing over ssh unless `security.pam.services.sshd` gains `pam_nologin`.
`pam_nologin` never refuses root, so adding it would leave the admin door alone.
That change is `IMP-011`.
