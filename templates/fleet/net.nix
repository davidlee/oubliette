# Single source of truth for the host<->guest link. A /30 point-to-point tap:
# no bridge, no LAN exposure, and deliberately no default route in the guest —
# the only way out is the allowlist proxy on the host end.
#
# Handed to mkFleet in flake.nix, which threads it to the guest and to the
# host-side NixOS module, so an address is never spelled twice. Every capsule's
# link is identical inside its own namespace, so these are one link's values,
# not one per slot.
#
# One port, not two. The host initiates git in both directions over ssh, so
# there is no git service to reach and nothing to allow (NOTES item 18).
{
  tap = "vm-capsule";
  host = "10.99.0.1";
  guest = "10.99.0.2";
  prefix = 30;
  mac = "02:00:00:00:99:02";
  proxyPort = 3128;
}
