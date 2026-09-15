Observed 2026-09-15 on slot `b` (`loginctl list-sessions`, nobody connected):
sessions for `agent` on `ttyS0` (`serial-getty@ttyS0.service`) and on `seat0`/`tty1`
(`getty@tty1.service`), plus the `systemd --user` manager, all in
`user-1000.slice`. `vm/capsule.nix` sets `services.getty.autologinUser`, and
NixOS applies it to every getty, not only the serial console.

- **Any test that excludes "the console's session" by naming one tty always
  finds another.** Exclude getty autologins by the session's logind `Service`
  instead (SL-002 RV-001 F-10).
- **Stopping one getty does not keep agent out.** After `systemctl stop
  user-1000.slice` with only the ttyS0 getty stopped, `getty@tty1` logged agent
  back in within five seconds. Stop both: `system-getty.slice` and
  `system-serial\x2dgetty.slice`.
- `systemctl stop user-1000.slice` is synchronous (51 ms there) and leaves no
  process owned by agent: the structural way to quiesce the agent, instead of
  `pgrep`/`pkill -u agent`.
