# IMP-011: Block agent logins while reset-home runs, with pam_nologin in the guest's sshd stack

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

SL-002's `capsule-reset-home` quiesces the guest (stops the gettys and
`user-1000.slice`) and **detects** an agent login that arrives during the reset,
failing loudly so the operator runs it again (`RV-001` `F-7`). It does not
**prevent** one.

Preventing one needs `pam_nologin` in the guest's sshd PAM stack. Checked
2026-09-15 on slot `b`: the guest's sshd runs `UsePAM yes`, `/etc/pam.d/sshd` has
no `pam_nologin`, and OpenSSH skips its own `/etc/nologin` check when PAM is on
(`openssh-10.5p1/session.c:1502`). So touching `/etc/nologin` today refuses
nothing.

The change: add `pam_nologin` to `security.pam.services.sshd` in the guest
(`vm/capsule.nix`); have `capsule-reset-home` write `/etc/nologin` before
quiescing and remove it in its exit trap; keep the detection check as a
backstop. A crash leaves `/etc/nologin` on the guest's tmpfs `/etc`, which
refuses agent logins until the next stop/start; that is the safe direction.
`pam_nologin` does not refuse root, so the admin door is unaffected. It needs a
live check that an agent login is refused while the file exists, because the
F-7 spike's own attempt at that could not be read (a `ssh true` session closes
before a later check sees it).
