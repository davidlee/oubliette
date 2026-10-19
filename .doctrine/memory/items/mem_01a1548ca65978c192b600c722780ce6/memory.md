`ssh -G -F /dev/null x` resolves `globalknownhostsfile /etc/ssh/ssh_known_hosts
/etc/ssh/ssh_known_hosts2` (checked 2026-10-20). Setting `UserKnownHostsFile`
does not change that. A key in a global file is accepted under
`StrictHostKeyChecking=yes`, so a door promising "refuse before first contact"
or "one trust store per room" (DEC-047) must also set `GlobalKnownHostsFile none`.
pi-env already does (dist/ssh.js:67); oubliette's room doors did not until
SL-008 (RV-023 F-2, DEC-055).
