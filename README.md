# DAG-based Multichain Architecture — TLA⁺ Specifications

Mechanised verification, with the TLC model checker, of the claims of

- **[DAG]** M. Kotov, S. Toliupa, *Scaling Multichain Systems using
  DAG-based Architecture* — the article under verification;
- **[Tree]** M. Kotov, *Tree-based state sharding for scalability and load
  balancing in multichain systems*, Cybersecurity: Education, Science,
  Technique 2(26), 392–408, 2024, doi:10.28925/2663-4023.2024.26.702 —
  the architecture [DAG] generalises; its communication modes are the ones
  modelled here.

The articles are checked as published. Where a claim fails, the
counterexample and a proposed amendment are documented, and the amendment
is checked in the same model. Every mechanism the articles argue for is a
switch: off, it must produce a counterexample; on, the property must hold.
[`docs/resolutions.md`](docs/resolutions.md) collects the amendments into
the resolved architecture and checks them together.

## Summary

- **45 TLC runs, all with their expected verdict** (21 hold; 24 are
  violated as intended: mutations, published readings found wanting, and
  witnesses). `make quick` runs 43 of them in about 3 minutes; `make all`
  adds two larger-bound rows (about 2 more minutes).
- **What holds as published.**
  - The structural consequences of [DAG] §2.1: the backbone is a forest,
    roles follow from degrees, and cross edges keep the graph acyclic.
  - Structured names are unique and resolvable.

  All of these hold on every topologically numbered system with up to
  five chains (four for acyclicity). Transfers conserve supply and stay
  backed, which the model guarantees by construction.
  [Tree]'s two safeguards are encoded with the attacks they prevent:
  locking upward transfers, and child validators that only observe.
- **What does not.**
  - One **Defect**: layering (5) is not always achievable (118 of the 508
    numbered systems with up to four chains).
  - Three **Gaps**:
    - the rules do not ensure that chains can reach each other;
    - a refused multi-hop transfer ends on an intermediate chain;
    - BR = 3 holds where unbacked value originates, not where it
      circulates, although §3.7 admits that faults on coordination chains
      may propagate.
  - Two characterisations: cross edges add security only if every parent
    confirms, and a shared validator pool makes the members' governance
    structures the blast radius (all of `gu5`).
- **Resolved.** [`docs/resolutions.md`](docs/resolutions.md) gives each
  finding an amendment:
  - (5′) longest-path layering;
  - (6) connectivity;
  - a hop-by-hop refund;
  - proof of validity only between siblings that share two parents with
    independent validators, all of which confirm; otherwise transfers go
    through the parent.

  With all of them on:
  - transfers conserve supply and settle at their origin or target;
  - every transfer ends, unless a compromised chain holds the unit or is
    asked to credit it;
  - no honest chain holds unbacked value whose provenance avoids the
    compromised chain.

  This holds on all four scenarios, with no compromise and with any one
  chain compromised (`tr_amended`, `tr_amended_tree`, `tr_amended_gu`,
  `tr_amended_path`), and at larger bounds for two of them.

## Claims

| Claim | Source | Rows | Verdict |
|---|---|---|---|
| The backbone is a forest of rooted out-trees | [DAG] §2.1, (3) | `st_forest` | Holds |
| Roles follow from backbone degrees | [DAG] §2.1 | `st_roles` | Holds |
| Cross edges keep the graph acyclic | [DAG] (4) | `st_cross` | Holds |
| Layering (5) is always achievable | [DAG] §2.1 | `st_layer_pub` / `st_layer_amd`, `st_layer_relaxed` | **Defect**; exact condition holds; longest-path layering (5′) always exists |
| Structured names are unique and resolvable | [DAG] §2.3 | `rt_names` | Holds |
| Distant chains can communicate | [DAG] §2.3, Conclusions | `rt_reach_pub` / `rt_reach_amd` | **Gap**; holds with a connectivity condition |
| Transfers conserve supply and stay backed | [Tree] eqs. 3–8 | `tr_full_tree3`, `tr_full_dag5` | Holds (by construction of the model) |
| Upward transfers must lock, not use proof of validity | [Tree] | `tr_up_pov` / `tr_up_lock` | Consistent: the modelled attack needs proof of validity upward |
| Child validators only observe the parent | [Tree] | `tr_obs_off` / `tr_obs_on` | Consistent: the modelled spread needs child validators voting on the parent |
| Spillover stays in a governance group (BR = 3) | [DAG] §3.1, §3.7 | `tr_valid_group` / `tr_valid_circ`, `tr_multi_all`, `tr_multi_gu` / `tr_amended`, `tr_amended_tree`, `tr_amended_gu`, `tr_amended_path` | **Gap**: holds where unbacked value originates, not where it circulates; contained when siblings use proof of validity only with two independent shared parents, all confirming |
| Cross edges add validation | [DAG] Conclusions, §3.7 SS = 3 | `tr_valid_backbone` / `tr_valid_all` | Characterisation: only if every parent validates |
| Multi-hop transfers settle | [Tree] | `tr_unwind_pub` / `tr_unwind_amd` | **Gap**; holds with hop-by-hop refund |
| A shared validator pool | [DAG] §2.2 | `tr_gu_spread`, `wt_gu_member` | Characterisation: the blast radius is the governance structures of every member (all of `gu5`; without the pool, r1's {r1, a, b}) |
| The resolved transfer rules, together | [`docs/resolutions.md`](docs/resolutions.md) | `tr_amended`, `tr_amended_tree`, `tr_amended_gu`, `tr_amended_path`, `tr_amended_big`, `tr_amended_path_big` | Holds with no compromise or any one chain compromised |

Not checked: the scoring model of [DAG] §3 (an assessment method over cited
figures); time, fees and throughput.

## Documentation

| Document | Content |
|---|---|
| [`docs/model.md`](docs/model.md) | what the modules model and abstract, scenarios, switches, properties |
| [`docs/results.md`](docs/results.md) | every row's verdict and numbers, and how to read them |
| [`docs/finding-layering.md`](docs/finding-layering.md) | layering (5) is not always achievable |
| [`docs/finding-connectivity.md`](docs/finding-connectivity.md) | the structural rules do not guarantee reachability |
| [`docs/finding-multihop-unwind.md`](docs/finding-multihop-unwind.md) | a refused multi-hop transfer ends on an intermediate chain |
| [`docs/finding-containment.md`](docs/finding-containment.md) | unbacked value leaves the governance group |
| [`docs/resolutions.md`](docs/resolutions.md) | every finding's resolution: the amended rule, alternatives, cost, checks; the resolved architecture |

## Files

| Path | Content |
|---|---|
| `spec/DagStructure.tla` | structure, naming and reachability, exhaustive over small systems |
| `spec/DagTransfer.tla` | transfers between chains, compromise and containment |
| `tools/gen_models.py` | the row table: generates `models/*.cfg`, `models/expect.tsv`, `models/rows.mk` |
| `tools/check.py` | compares every log's verdict with its expectation; `--md` prints the results table |
| `tools/trace.py` | copies a counterexample from a log to `traces/` |
| `models/`, `logs/`, `traces/` | configurations, TLC output of the reported runs, cited counterexamples |
| `Makefile`, `run.sh` | one target per row, `quick`, `all`; one row outside make |

## Running

Requires Java 11 or later, GNU make and Python 3. The Makefile downloads
TLC (`tla2tools.jar`, release v1.7.4, TLC 2.19) and checks its SHA-256.

```bash
make quick                 # every row but the two slow ones, about 3 min, then the verdict check
make all                   # every row, about 5 min
make st_layer_pub          # one row
./run.sh tr_up_pov         # one row outside make
python3 tools/check.py     # verdicts of the existing logs
```

Runs use one worker so that counterexamples are shortest and the numbers in
`docs/results.md` reproduce (`WORKERS=auto` overrides).

## Citing

Cite the tag `v1`, not `main`.
