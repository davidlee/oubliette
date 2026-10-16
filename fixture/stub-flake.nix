# A tool-set flake that is nobody's, as a plain value: the fixture target's
# `flake`. Its target declares `toolsPackage = null`, so nothing reads a package
# out of it; it exists because every target is paired with one (fleet.nix). A
# value rather than a flake input, so nothing reaches oubliette's lock.
{packages.x86_64-linux = {};}
