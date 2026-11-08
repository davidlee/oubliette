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
# there is no git service to reach and nothing to allow (NOTES item 18). A
# declared model door is a second, declared port, not a git service.
{
  tap = "vm-capsule";
  host = "10.99.0.1";
  guest = "10.99.0.2";
  prefix = 30;
  mac = "02:00:00:00:99:02";
  proxyPort = 3128;

  # A model door: one optional port on the host's end of the link, relayed to
  # a model gateway's unix socket for each slot that declares a door in
  # capsules.nix (DEC-069, DEC-071). Absent, no slot on this host may declare
  # one. The port is 1024-65535 and neither `proxyPort` nor 22; the relay runs
  # as the host module's `owner`, so the socket must be one that user can open.
  #
  # modelDoor = {
  #   port = 4000;
  #   socket = "/run/llm-gateway-client/api.sock";
  # };
}
