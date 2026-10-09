# DAG multichain model: scope, abstractions and properties

Two TLA⁺ modules check the claims of the DAG article — M. Kotov,
S. Toliupa, *Scaling Multichain Systems using DAG-based Architecture*
([DAG]) — together with the communication modes it inherits from the tree
article — M. Kotov, *Tree-based state sharding for scalability and load
balancing in multichain systems*, Cybersecurity: Education, Science,
Technique 2(26), 2024, doi:10.28925/2663-4023.2024.26.702 ([Tree]). Section
and equation numbers refer to these articles.

## Verdict classes

Every row of [`results.md`](results.md) supports one verdict:

- **Holds** — checked within the stated bounds;
- **Defect** — fails under every reasonable reading of the text;
- **Gap** — the literal reading fails, a completion consistent with the
  text holds; the completion is the proposed amendment;
- **Characterisation** — not claimed by the articles; the model measures it.

Each mechanism the articles argue for is a constant: switched off it must
produce a counterexample (mutation rows); switched on the property must hold.
Witness rows negate the scenario a passing row relies on and must be
violated, so no passing row is vacuous.

## The architecture in brief

A system is a quadruple (V, Eₕ, Eₓ, ℓ) ([DAG] §2.1): chains V, backbone
edges Eₕ with backbone in-degree ≤ 1 (3), cross edges Eₓ disjoint from Eₕ
(2), and a level function ℓ strictly increasing along every edge (1), (4).
Roles are derived from backbone degrees: roots have no backbone parent,
boughs have backbone children, springs have none. Governance structures
are G_d (parent–child pairs) and G_u (an agreed group of boughs sharing a
rotated validator pool) (§2.2). Chains are named DNS-like from their root
(§2.3).

Transfers use the [Tree] modes: lock-based transfers between a parent and
a child, validated by the receiving chain on its own rules (eqs. 3–8);
proof of validity between siblings, verified against the parent's
aggregate commitment B_t (eqs. 9–14; [DAG] §3.7 "similar to Polkadot");
multi-hop transfers along the backbone (eq. 15); and governance links,
here the cross edges, attested by a committee S_ij ⊆ V(i) ∩ V(j)
(eqs. 16–19).

## `spec/DagStructure.tla` — structure (constant level)

All systems with up to `MaxN` chains are enumerated and each claim is
checked on every one; the smallest counterexample is kept, in the pattern
of `LemmaOne.tla` of the RSDP split-brain artifact.

- `Systems(n)`: chains numbered in a topological order, so every edge goes
  from a smaller to a larger number. No generality is lost: condition (1)
  gives every valid system such an order. 1, 3, 24, 480, 23,040 systems for
  n = 1..5.
- `Forests(n)`: every backbone with in-degree ≤ 1 and no cycle, numbered
  arbitrarily — for the claims about (3) itself.

| Row | Claim | Source |
|---|---|---|
| `st_forest` | in an acyclic G, (3) makes the backbone a disjoint union of rooted out-trees | §2.1, consequences of (3) |
| `st_roles` | bough and spring partition V; there is a root | §2.1, node roles |
| `st_cross` | a cross edge forward in a level function cannot close a cycle | (4) |
| `st_layer_pub` | (5) "is always achievable by strict topological numbering" | §2.1, after the validity list |
| `st_layer_amd` | amended: (5) is achievable iff the root-offset difference constraints are satisfiable | amendment |
| `st_layer_relaxed` | resolution (5′): the longest-path ranking puts every edge one or more levels down | amendment |
| `rt_names` | structured names are unique and resolve from the root directory in depth + 1 labels | §2.3 |
| `rt_reach_pub` | chains anywhere in the system can communicate | §2.3, Conclusions |
| `rt_reach_amd` | amended: with the underlying graph of E connected, the name-based route reaches every chain | amendment |
| `ws_multiroot`, `ws_crossskip` | witnesses: systems with several roots linked by a cross edge, and cross edges skipping levels, are enumerated | — |
| `ws_longbackbone` | witness: under (5′) some backbone edge spans two levels or more | — |

`st_cross`, `st_layer_pub` and `st_layer_amd` search level functions or
root offsets per system and run at `MaxN = 4`; the others at `MaxN = 5`.

Layering. Backbone edges go exactly one level down under (5), so a layering
is ℓ(v) = off(root of v) + depth(v) for root offsets `off`. A cross edge
(u, v) then needs off(root v) − off(root u) ≥ depth(u) − depth(v) + 1: a
system of difference constraints over the roots. `Feasible` decides it by
Bellman–Ford longest-path relaxation; `Layerable` searches offsets in
0..(R − 1)(n − R + 1), which covers the longest-path solution of any
satisfiable system (R roots; a depth is at most n − R). The two agree on
every system with up to four chains (`st_layer_amd`). The resolution's
normalisation (5′) takes ℓ(v) as the length of a longest path ending at v
(`LP`, a recursion over the topological numbering); `RelaxedOK` checks
that every edge then goes down (`st_layer_relaxed`).

Name-based route (`rt_reach_amd`). Inside a backbone tree: up to the lowest
common ancestor and down. Between trees: over a cross edge, choosing the
sequence of trees by breadth-first search over trees linked by cross edges.
Every hop must be an edge of E in either direction.

## `spec/DagTransfer.tla` — transfers and compromise

### Scenarios

| Scenario | Backbone | Cross edges | Units | Routes |
|---|---|---|---|---|
| `tree3` | r→a, r→b | — | 2 of r's asset, 1 of a's | every pair, direct |
| `path4` | r→a→b, r→c | — | 1 of b's | b→a→r→c and back |
| `dag5` | r1→a, r1→b, r2→c | r2→a, r2→b | 1 of a's, 1 of c's | a↔b (siblings), c→r2→a, a→r2→c |
| `gu5` | as `dag5` | as `dag5` | as `dag5` | as `dag5`; G_u = {r1, r2} |

Chains are numbered r = 1, a = 2, b = 3, c = 4 (`tree3`, `path4`) and
r1 = 1, r2 = 2, a = 3, b = 4, c = 5 (`dag5`, `gu5`).

### Units and provenance

A unit is a path ⟨h, c₁, …, c_k⟩: locked in escrow on h for c₁, on c₁ for
c₂, …, and spendable on c_k as Wrap(c_{k−1}, … Wrap(h, Native(h))) —
[Tree]'s wrapped assets, whose nesting is the provenance. Moving back to
c_{k−1} burns the wrapper and releases the escrow. Honest actions neither
create nor duplicate a real unit, so supply conservation ([Tree] eq. 5)
and backing (eqs. 3–4, 8) hold by construction for them; `Conservation`
and `Backed` guard the encoding. A *fake* unit has no escrow behind it and
arises only from a compromised chain's actions. An honest chain releases
escrow only if it holds it.

### Adversary

At most one chain c₀ is compromised, chosen at the start among the
candidates of `COMPROMISE` (0 stands for no compromise, so one row can
cover the honest case and every single compromise). A compromised chain
may mint units on its own ledger (`ForgeUnit`), invent locks in the
aggregate it publishes for its children (`ForgeAgg`), and — only under
`UP = "pov"` — have its parent apply a proved transition that releases
escrow the parent holds for another chain (`PovTheft`). One adversary
controls every compromised chain: an invented lock appears in the
aggregate of each of them. Merkle proofs are membership in a committed
root, under the articles' collision-resistance assumption.

An honest chain refuses to release escrow it does not hold. A refused
mint of a lock that only a compromised aggregator claimed lets the claim
lapse: the honest source never locked anything, so it unlocks nothing.

Validators are abstracted into whom a compromise reaches (`Spread`):
without the observer rule V(c) ∩ R(p(c)) = ∅ a child's validators vote on
its parent, and a compromised child takes the parent over (worst case); a
United Governance Structure rotates one pool over its members, so a
compromise reaches every member (worst case).

### Switches

| Constant | Values (published first) | Source |
|---|---|---|
| `UP` | `"lock"` / `"pov"` | [Tree]: upward transfers lock, because under proof of validity a hijacked child "could convince its Bough to illegitimately transfer assets" |
| `OBSERVERS` | `TRUE` / `FALSE` | [Tree]: child validators observe the parent and do not validate it |
| `VALIDATE` | `"backbone"` / `"all_parents"` / `"multi_parent"` | [DAG] Conclusions, "multiple higher-level validations"; §3.7, SS = 3. `"multi_parent"` is the resolution: every parent confirms, and only a chain with two parents or more accepts sibling transfers |
| `UNWIND` | `"published"` / `"amended"` | [Tree] defines only the single-hop outcome; amended: refund hop by hop |
| `ALLOW_REJECT` | `FALSE` / `TRUE` | an honest chain may refuse a mint |
| `COMPROMISE` | `{}`, one chain, or a set of candidates for c₀ (0 = none) | c₀ |

Bounds: `MaxTx = 2` transfers and `MaxForge = 1` fake unit per behaviour.

### Properties

| Name | Kind | Formalises |
|---|---|---|
| `TypeOK` | invariant | well-formedness |
| `Conservation` | invariant | [Tree] eq. 5 (structural) |
| `Backed` | invariant | [Tree] eqs. 3–4, 8: without a compromise no fake unit exists (structural) |
| `SettlesSafe` | invariant | a transfer ends at its origin or its requested target |
| `Terminates` | liveness | every transfer ends (weak fairness on honest sending and validation) |
| `ProvenanceContained` | invariant | no honest chain holds a fake unit whose provenance avoids every compromised chain |
| `GroupContained` | invariant | BR = 3 ([DAG] §3.7, [Tree]) for where damage starts: the compromise stays in Gov(c₀), and unbacked value originates only in Blast = ⋃ Gov(c) over compromised c |
| `CirculationContained` | invariant | BR = 3 for where damage goes: damaged chains stay in Blast while fake units circulate |

A damaged chain holds a fake unit whose provenance names no compromised
chain. Units that name one are the compromised chain's own assets, which
its compromise devalues in any multichain system ([DAG] §3.4 still scores
Cosmos BR = 5), so they are not counted.

Gov(c) is c, its backbone parent and children (G_d as in [Tree] eq. 1) and
any G_u containing c. [DAG] eq. 9 restricts G_d to boughs, which would put
springs in no governance structure and leave BR undefined for them; the
model uses [Tree]'s definition.

### The resolved protocol

`tr_amended` (`dag5`) and `tr_amended_path` (`path4`) switch every
resolution on — `VALIDATE = "multi_parent"`, `UNWIND = "amended"`,
refusals allowed — and take every chain, or none, as c₀. `tr_multi_all`
and `tr_multi_gu` show that both halves of the two-parent condition are
needed. See [`resolutions.md`](resolutions.md).

## Notation notes

These do not change any verdict and are not findings:

- (9) writes G_d's pairs as (v, p(v)), child → parent, while stating
  E_g ⊆ Eₕ, whose pairs are parent → child.
- (11) defines G_u as all of V_u × V_u, so the transitivity sentence after
  it holds trivially and E_u is unused.
- A root with children is both root and bough; a root without children is
  both root and spring.

## Not checked

- The scoring model of [DAG] §3 (L\*, T\*, C\*, DA\*, CSS, Table 1): an
  assessment method over cited figures, not behaviour of the system.
- Time, fees, finality and throughput; role changes (spring → bough) and
  topology changes at run time.
- Validator sets inside a chain beyond the spread relation; consensus
  inside a chain is atomic and honest unless the chain is compromised.
