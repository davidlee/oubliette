`nix build .#<suite>` on this repo resolves `git+file:///home/david/dev/oubliette`.
A dirty tree is fine — nix picks up **modified tracked files** without a commit.
An **untracked** file is not there at all, so a newly created `vm/guest-path.nix`
fails as:

    error: getting status of '/nix/store/…-source/vm/guest-path.nix': No such file or directory

`git add` the file — no commit needed. This is a different rule from
[[mem.fact.oubliette.git-file-inputs-read-committed-head]], which is about the
*target's* flake needing a commit before `nix flake update target` sees it;
here the tree is this repo's own and staging is enough.
