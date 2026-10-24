Seen locking SL-009's design (RV-025, 2026-10-24):

- The `reviewing→locked` edge refuses while any BLOCKER/MAJOR finding has no route ("severe findings carry no route"). `review amend` only works on *answered* findings, so a verified one needs the raiser to reopen, the responder to re-dispose with `--route`, and the raiser to verify again: an extra round trip. Pass `--route review|demonstrate|probe|control|…` on the **first** `review dispose` of every severe finding.
- The human lane's `section-reviewed` is recorded by declaring `{"subject":"att-N","attests":"sec-N","reviewer":"human"}` per section in `design apply`; a bare `checkpoint_act` of `section-reviewed` is refused ("binds to per-section coverage").
