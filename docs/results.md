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
| `st_forest` | holds | ✓ holds | 1 | depth 1 | 11s |
| `st_roles` | holds | ✓ holds | 1 | depth 1 | 11s |
| `st_cross` | holds | ✓ holds | 1 | depth 1 | 00s |
| `st_layer_pub` | violated:NoViolation | ✗ NoViolation | - | - | 00s |
| `st_layer_amd` | holds | ✓ holds | 1 | depth 1 | 00s |
| `st_layer_relaxed` | holds | ✓ holds | 1 | depth 1 | 12s |
| `rt_names` | holds | ✓ holds | 1 | depth 1 | 14s |
| `rt_reach_pub` | violated:NoViolation | ✗ NoViolation | - | - | 11s |
| `rt_reach_amd` | holds | ✓ holds | 1 | depth 1 | 27s |
| `ws_multiroot` | violated:NoViolation | ✗ NoViolation | - | - | 11s |
| `ws_crossskip` | violated:NoViolation | ✗ NoViolation | - | - | 35s |
| `ws_longbackbone` | violated:NoViolation | ✗ NoViolation | - | - | 11s |
| `tr_full_tree3` | holds | ✓ holds | 163 | depth 7 | 00s |
| `tr_full_dag5` | holds | ✓ holds | 70 | depth 11 | 00s |
| `tr_up_pov` | violated:ProvenanceContained | ✗ ProvenanceContained | 413 | trace 5 | 00s |
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
| `tr_amended_tree` | holds | ✓ holds | 9714 | depth 17 | 02s |
| `tr_amended_gu` | holds | ✓ holds | 13094 | depth 17 | 02s |
| `tr_amended_path` | holds | ✓ holds | 2582 | depth 24 | 00s |
| `tr_amended_big` | holds | ✓ holds | 475047 | depth 26 | 01min 24s |
| `tr_amended_path_big` | holds | ✓ holds | 134196 | depth 36 | 11s |
| `tr_multi_all` | violated:ProvenanceContained | ✗ ProvenanceContained | 35 | trace 3 | 00s |
| `tr_multi_gu` | violated:ProvenanceContained | ✗ ProvenanceContained | 46 | trace 3 | 00s |
| `tr_gu_spread` | holds | ✓ holds | 971 | depth 13 | 00s |
| `wt_forge` | violated:NoForgedOnHonest | ✗ NoForgedOnHonest | 484 | trace 5 | 00s |
| `wt_multihop` | violated:NoMultiHop | ✗ NoMultiHop | 8 | trace 8 | 00s |
| `wt_dualvalid` | violated:NoDualValid | ✗ NoDualValid | 15 | trace 4 | 00s |
| `wt_refund` | violated:NoRefund | ✗ NoRefund | 5 | trace 4 | 00s |
| `wt_gu_member` | violated:NoGuSpread | ✗ NoGuSpread | - | - | 00s |
| `wt_tree3` | violated:NoSiblingDone | ✗ NoSiblingDone | 55 | trace 4 | 00s |
| `wt_dag5` | violated:NoCrossTree | ✗ NoCrossTree | 33 | trace 6 | 00s |
| `wt_obs` | violated:NoForgedOnHonest | ✗ NoForgedOnHonest | 33 | trace 5 | 00s |
| `wt_amended` | violated:NoRefund | ✗ NoRefund | 178 | trace 4 | 00s |
| `wt_detour` | violated:NoSiblingDone | ✗ NoSiblingDone | 1890 | trace 6 | 00s |
| `wt_amended_gu` | violated:NoSiblingDone | ✗ NoSiblingDone | 1011 | trace 6 | 00s |
| `wt_amended_path` | violated:NoRefund | ✗ NoRefund | 60 | trace 4 | 00s |

## Reading the results

- **Structure, [DAG] §2.1.** The backbone is a forest, roles are well
  defined and cross edges keep the graph acyclic, on every topologically
  numbered system with up to five chains (four for `st_cross`). The claim
  that layering (5) is always achievable is false: 118 of the 508 numbered
  systems with up to four chains admit no layering, the smallest with
  three chains — see [`finding-layering.md`](finding-layering.md). The
  amended condition agrees with brute force on all 508, and the
  longest-path layering (5′) exists on all 23,548 systems with up to five
  chains (`st_layer_relaxed`).
- **Naming and reachability, [DAG] §2.3.** Names are unique and resolve on
  all 23,548 systems with up to five chains, but 2,627 of them have chains
  that cannot reach each other; a connectivity condition restores
  reachability — [`finding-connectivity.md`](finding-connectivity.md).
- **Transfers, [Tree] modes on the DAG.** Without a compromise, transfers
  conserve supply and stay backed (by construction of the model) and
  always end at their origin or target (`tr_full_*`). A refused multi-hop
  transfer ends on an intermediate chain under the published rules —
  [`finding-multihop-unwind.md`](finding-multihop-unwind.md).
- **[Tree]'s design arguments, as encoded.** Upward proof of validity lets
  a compromised child drain escrow its parent holds for a sibling, whose
  wrapper then names no compromised chain (`tr_up_pov`); locking removes
  that attack (`tr_up_lock`). Without the observer rule a compromise climbs
  the backbone (`tr_obs_off`); with it, it does not (`tr_obs_on`). The
  model builds both attacks in, so these pairs show it is consistent with
  [Tree]'s arguments; they are not independent evidence for them.
- **Blast radius, [DAG] §3.7 (BR = 3).** Unbacked value is created only
  inside the governance structures of the compromised chains
  (`tr_valid_group`). It does not stay there: an honest sibling credited
  through a forged aggregate passes the unbacked wrapper on, and since its
  provenance names only honest chains nobody downstream can tell
  (`tr_valid_circ`). §3.7 admits that faults on coordination chains may
  propagate, but its score bounds the propagation to a governance group.
  BR = 3 therefore holds for where damage originates, not for where it
  travels — [`finding-containment.md`](finding-containment.md).
- **Cross edges as extra validation, [DAG] Conclusions and SS = 3.** With
  only the backbone parent validating, a compromised parent forges a
  sibling transfer (`tr_valid_backbone`). If every parent of the receiving
  chain must confirm the commitment, the forgery fails and nothing leaves
  the group (`tr_valid_all`): the security gain from cross edges exists
  only under that reading, which the article should state. It also needs
  two shared parents, and independent ones: siblings whose only parent is
  compromised (`tr_multi_all`), or whose two shared parents share a
  validator pool (`tr_multi_gu`), still credit the forgery.
- **Shared validator pool, [DAG] §2.2.** In a United Governance Structure a
  compromise reaches every member (`wt_gu_member`), and the blast radius
  becomes the governance structures of every member: in `gu5` all five
  chains, against r1's own {r1, a, b} without the pool. `tr_gu_spread`
  measures this and cannot fail there, since the blast radius is the whole
  system. The pool lowers the probability of a 51 % attack, which TLC
  cannot measure, at the price of a wider blast radius.
- **The resolved transfer rules.** Siblings use proof of validity only
  with two independent shared parents, all of which confirm; otherwise
  they go through the parent; a refused transfer is refunded hop by hop.
  On all four scenarios, with no compromise or any one chain compromised:
  - no honest chain ever holds an unbacked unit that names no compromised
    chain;
  - every transfer ends at its origin or target;
  - every transfer ends, unless a compromised chain holds the unit or is
    asked to credit it.

  Rows: `tr_amended`, `tr_amended_tree`, `tr_amended_gu`,
  `tr_amended_path`. The same verdicts hold at three transfers and two
  forged units (`tr_amended_big`, `tr_amended_path_big`). Rationale,
  alternatives and cost of each amendment:
  [`resolutions.md`](resolutions.md).
- **Witnesses.** Each passing transfer row is backed by a witness or a
  violated row in the same scenario with the same switches, showing that
  the scenario it relies on occurs:

  | Passing row | Backed by |
  |---|---|
  | `tr_full_tree3`, `tr_full_dag5` | `wt_tree3`, `wt_dag5` |
  | `tr_up_lock` | `wt_forge` |
  | `tr_obs_on` | `wt_obs` |
  | `tr_valid_group` | `tr_valid_backbone`, `tr_valid_circ` |
  | `tr_valid_all` | `wt_dualvalid` |
  | `tr_unwind_amd` | `wt_refund` |
  | `tr_amended` | `wt_amended` |
  | `tr_amended_tree` | `wt_detour` |
  | `tr_amended_gu` | `wt_amended_gu` |
  | `tr_amended_path` | `wt_amended_path` |
  | `tr_gu_spread` | `wt_gu_member` |

  The larger-bound rows contain every behaviour of `tr_amended` and
  `tr_amended_path`, so those witnesses carry over. `ws_*` show that the
  structural enumeration contains the cases the claims are about.

## Reproducing

`make quick` runs every row except the two larger-bound ones in about 3
minutes, and `make all` runs every row in about 5. Both end with
`tools/check.py`, which exits non-zero if any verdict differs from its
expectation, if a row has no log, or if a log is stale: each log's first
line records the SHA-256 of the module, the configuration and the jar it
was run with. `make <row>` or `./run.sh <row>` runs one row. The
configurations are generated by `python3 tools/gen_models.py` from one
table; regenerate them rather than editing them, so rows stay comparable.
`WORKERS=auto make quick` is faster. Verdicts do not change, nor do the
state counts of rows that hold. A violated row stops wherever a worker
first meets the violation, so its count and trace may differ.
