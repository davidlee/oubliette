# What a profile's *name* may be, at eval — SL-001 design sec-2.
#
# Builtins only, so `capsules.nix` can import it without `pkgs`, and
# `host/profile-cases.nix` imports the same file. The grammar has a second
# spelling in `host/profile.nix`'s `profileLoad`, because that one runs in the
# shell; the two are held together by a case that runs one table of names
# through both (`one grammar, two spellings`), not by this comment.
#
# `profileLoad`'s rule, which reserves `-` because `recordField`
# (host/record.nix) prints it for an absent field, so a profile of that name
# would read as none — plus four characters that matter only because a declared
# name is rendered into the front end's text: a newline or tab breaks a line-based
# reader, and a `$` or backtick inside single quotes is shellcheck's SC2016,
# which `writeShellApplication` makes a build failure.
p:
p
!= ""
&& p != "."
&& p != ".."
&& p != "-"
&& builtins.match ".*[/\n\t$`].*" p == null
