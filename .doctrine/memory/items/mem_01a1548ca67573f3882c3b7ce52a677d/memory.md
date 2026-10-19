man systemd.exec, RuntimeDirectoryPreserve=: default `no` removes the
directories on every stop; `restart` keeps them across restarts; `yes` keeps
them across stops. The room relay (host/services.nix:348) uses the default, so
`/run/capsule-room/<r>` and its socket vanish whenever the relay stops or
restarts. A bwrap `--ro-bind` of that directory then points at a dead inode
until the jail restarts. Bind the parent instead.

Before SL-008 nothing but a relay start created the parent `/run/capsule-room`
(root 0755, made by systemd as an intermediate directory), so a jail started
before any room could not bind it at all (RV-023 F-3). DEC-056 adds a tmpfiles
rule for it. Not yet observed live: that the parent survives a relay stop
(documented behaviour; only the configured path is removed).
