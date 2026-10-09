# DAG multichain model: results

TLC 2.19 of 08 August 2024 (rev 5a47802, release v1.7.4, the
`tla2tools.jar` the Makefile fetches and checks), OpenJDK 21, Linux, one
worker. With one worker breadth-first search is exact: counterexamples are
shortest and depths are true diameters, so the numbers below reproduce.
Logs: `logs/<row>.log`; counterexamples cited in the docs: `traces/`.

The table is generated from the logs by `python3 tools/check.py --md`;
*Expected* comes from the row table in `tools/gen_models.py`. A ✗ in
*Result* is a violated property: expected for mutations, published
readings found wanting, and witnesses. Rows that fail in the initial state
(the constant-level rows and the spread rows) report no state count.

| Row | Expected | Result | Distinct states | Depth / trace | Time |
|---|---|---|---|---|---|
| `st_forest` | holds | ✓ holds | 1 | depth 1 | 10s |
| `st_roles` | holds | ✓ holds | 1 | depth 1 | 11s |
| `st_cross` | holds | ✓ holds | 1 | depth 1 | 00s |
| `st_layer_pub` | violated:NoViolation | ✗ NoViolation | - | - | 00s |
| `st_layer_amd` | holds | ✓ holds | 1 | depth 1 | 00s |
| `st_layer_relaxed` | holds | ✓ holds | 1 | depth 1 | 12s |
| `rt_names` | holds | ✓ holds | 1 | depth 1 | 14s |
| `rt_reach_pub` | violated:NoViolation | ✗ NoViolation | - | - | 10s |
| `rt_reach_amd` | holds | ✓ holds | 1 | depth 1 | 27s |
| `ws_multiroot` | violated:NoViolation | ✗ NoViolation | - | - | 11s |
| `ws_crossskip` | violated:NoViolation | ✗ NoViolation | - | - | 36s |
| `ws_longbackbone` | violated:NoViolation | ✗ NoViolation | - | - | 11s |
| `tr_full_tree3` | holds | ✓ holds | 163 | depth 7 | 00s |
| `tr_full_dag5` | holds | ✓ holds | 70 | depth 11 | 00s |
| `tr_up_pov` | violated:GroupContained | ✗ GroupContained | 413 | trace 5 | 00s |
| `tr_up_lock` | holds | ✓ holds | 1269 | depth 8 | 00s |
| `tr_obs_off` | violated:GroupContained | ✗ GroupContained | - | - | 00s |
| `tr_obs_on` | holds | ✓ holds | 202 | depth 16 | 00s |
| `tr_valid_backbone` | violated:ProvenanceContained | ✗ ProvenanceContained | 30 | trace 3 | 00s |
| `tr_valid_group` | holds | ✓ holds | 691 | depth 13 | 00s |
| `tr_valid_circ` | violated:CirculationContained | ✗ CirculationContained | 226 | trace 6 | 00s |
| `tr_valid_all` | holds | ✓ holds | 420 | depth 12 | 00s |
| `tr_unwind_pub` | violated:SettlesSafe | ✗ SettlesSafe | 9 | trace 6 | 00s |
| `tr_unwind_amd` | holds | ✓ holds | 64 | depth 19 | 00s |
| `tr_amended` | holds | ✓ holds | 8287 | depth 17 | 01s |
| `tr_amended_path` | holds | ✓ holds | 2582 | depth 24 | 00s |
| `tr_multi_all` | violated:ProvenanceContained | ✗ ProvenanceContained | 35 | trace 3 | 00s |
| `tr_multi_gu` | violated:ProvenanceContained | ✗ ProvenanceContained | 46 | trace 3 | 00s |
| `tr_gu_spread` | holds | ✓ holds | 971 | depth 13 | 00s |
| `wt_forge` | violated:NoForgedOnHonest | ✗ NoForgedOnHonest | 484 | trace 5 | 00s |
| `wt_multihop` | violated:NoMultiHop | ✗ NoMultiHop | 8 | trace 8 | 00s |
| `wt_dualvalid` | violated:NoDualValid | ✗ NoDualValid | 15 | trace 4 | 00s |
| `wt_refund` | violated:NoRefund | ✗ NoRefund | 5 | trace 4 | 00s |
| `wt_gu_member` | violated:NoGuSpread | ✗ NoGuSpread | - | - | 00s |

## Reading the results

- **Structure, [DAG] §2.1.** The backbone is a forest, roles are well
  defined and cross edges keep the graph acyclic, on every system with up
  to five chains (four for `st_cross`). The claim that layering (5) is
  always achievable is false: 118 of the 508 systems with up to four chains
  admit no layering, the smallest with three chains — see
  [`finding-layering.md`](finding-layering.md). The amended condition
  agrees with brute force on all 508, and the longest-path layering (5′)
  exists on all 23,548 systems with up to five chains
  (`st_layer_relaxed`).
- **Naming and reachability, [DAG] §2.3.** Names are unique and resolve on
  all 23,548 systems with up to five chains, but 2,627 of them have chains
  that cannot reach each other; a connectivity condition restores
  reachability — [`finding-connectivity.md`](finding-connectivity.md).
- **Transfers, [Tree] modes on the DAG.** Without a compromise, transfers
  conserve supply, stay backed and always end at their origin or target
  (`tr_full_*`). A refused multi-hop transfer ends on an intermediate
  chain under the published rules —
  [`finding-multihop-unwind.md`](finding-multihop-unwind.md).
- **[Tree]'s design arguments hold.** Upward proof of validity lets a
  compromised child drain escrow its parent holds for a sibling
  (`tr_up_pov`); locking prevents it (`tr_up_lock`). Without the observer
  rule a compromise climbs the backbone (`tr_obs_off`); with it, it does
  not (`tr_obs_on`).
- **Blast radius, [DAG] §3.7 (BR = 3).** Unbacked value is created only
  inside the governance structures of the compromised chains
  (`tr_valid_group`, `tr_up_lock`, `tr_obs_on`, `tr_gu_spread`). It does not
  stay there: an honest sibling credited through a forged aggregate passes
  the unbacked wrapper on, and since its provenance names only honest
  chains nobody downstream can tell (`tr_valid_circ`). BR = 3 therefore
  holds for where damage originates, not for where it travels —
  [`finding-containment.md`](finding-containment.md).
- **Cross edges as extra validation, [DAG] Conclusions and SS = 3.** With
  only the backbone parent validating, a compromised parent forges a
  sibling transfer (`tr_valid_backbone`). If every parent of the receiving
  chain must confirm the commitment, the forgery fails and nothing leaves
  the group (`tr_valid_all`): the security gain from cross edges exists
  only under that reading, which the article should state. It also needs
  two parents, and independent ones: a chain whose only parent is
  compromised (`tr_multi_all`), or whose two parents share a validator
  pool (`tr_multi_gu`), still credits the forgery.
- **Shared validator pool, [DAG] §2.2.** In a United Governance Structure a
  compromise reaches every member (`wt_gu_member`), and the blast radius is
  the members and their children (`tr_gu_spread`). The pool lowers the
  probability of a 51 % attack, which TLC cannot measure, at the price of
  a wider blast radius.
- **The resolved transfer rules.** With every parent of a chain with two
  parents or more confirming sibling transfers and refunds on refusal, no
  honest chain ever holds an unbacked unit that names no compromised chain,
  every transfer ends at its origin or target, and every transfer ends —
  with no compromise or any one chain compromised (`tr_amended`,
  `tr_amended_path`). Rationale, alternatives and cost of each amendment:
  [`resolutions.md`](resolutions.md).
- Every passing row is backed by a witness showing that the scenario it
  relies on occurs (`ws_*`, `wt_*`).

## Reproducing

`make quick` runs every row in about 3 minutes and ends with
`tools/check.py`, which exits non-zero if any verdict differs from its
expectation. `make <row>` or `./run.sh <row>` runs one row. The
configurations are generated by `python3 tools/gen_models.py` from one
table; regenerate them rather than editing them, so rows stay comparable.
`WORKERS=auto make quick` is faster; verdicts and distinct-state counts do
not change, traces may be longer.
