# Finding: unbacked value leaves the governance group

Verdict: **Gap** in [DAG] §3.7 (BR = 3). Rows `tr_valid_circ`,
`tr_multi_all`, `tr_multi_gu` (violated) and `tr_valid_group`,
`tr_valid_all`, `tr_amended`, `tr_amended_path` (hold) of
`spec/DagTransfer.tla`.

## The published text

[DAG] §3.1 defines Blast Radius as the "extent of damage from a
compromised domain" and score 3 as "spillover limited to a governance
group". §3.7 gives the DAG architecture BR = 3. In the same section,
sibling communication is the dominant mode and works "similar to the
Polkadot's solution": the receiving chain verifies the sender's lock
against its parent's aggregate commitment ([Tree] eqs. 9–14). The
Conclusions add that the DAG "allows for improving the security properties
of the system by enabling multiple higher-level validations of
transactions", and §3.7 credits cross connections with additional shared
security (SS = 3). Neither says whether a sibling transfer needs the
confirmation of one parent or of several.

## What the model counts as damage

An honest chain is damaged when it holds a unit with no escrow behind it
whose provenance names no compromised chain (`Damaged`). Units whose
provenance names a compromised chain are that chain's own assets, made
worthless by its compromise. That happens in every multichain system, and
[DAG] §3.4 still scores Cosmos BR = 5, so these units are not counted.

## Counterexample

Scenario `dag5`: roots r1 = 1 and r2 = 2; r1 → a = 3, r1 → b = 4, r2 → c = 5;
cross edges r2 → a and r2 → b. r1 is compromised, and sibling transfers
are verified against the backbone parent only (`VALIDATE = "backbone"`).
Trace `traces/tr_valid_circ.trace.txt`:

| State | Action | path of fake unit 3 | Comment |
|---|---|---|---|
| 1 | Init | — | |
| 2 | ForgeAgg(r1) | ⟨4⟩, in flight to 3 | r1's aggregate claims b locked a unit for a; b did not |
| 3 | Credit | ⟨4, 3⟩ | a verifies against r1's aggregate and mints the wrapper |
| 4 | Start | ⟨4, 3⟩ | a's holder sends it to c, route a → r2 → c |
| 5 | SendHop | ⟨4, 3⟩ | a locks it for r2 |
| 6 | Credit | ⟨4, 3, 2⟩ | r2 mints a wrapper of it |

`CirculationContained` is violated: r2 holds an unbacked unit, and r2 is
outside r1's governance group {r1, a, b}. Its provenance ⟨b, a, r2⟩ names
only honest chains, so nothing tells r2, or c after it, that the unit is
unbacked. The unbacked value still *originates* inside the group (a is
r1's child): `GroupContained` holds in the same scenario
(`tr_valid_group`). BR = 3 therefore holds for where damage starts, not
for where it goes.

## Confirmation by every parent is not enough

With every parent's aggregate required (`VALIDATE = "all_parents"`), the
forgery fails in `dag5`, because a and b have a second parent, r2, whose
aggregate lacks the invented lock (`tr_valid_all`). It does not fail in
two other cases:

- `tr_multi_all` (`path4`, r compromised): a's only parent is r. "Every
  parent" is then r alone, which confirms its own forgery; a credits the
  unbacked unit in three steps.
- `tr_multi_gu` (`gu5`, r1 compromised): a's two parents r1 and r2 share
  one validator pool, so the compromise reaches both, and both
  aggregates carry the forged lock.

## Proposed amendment

> A chain credits a sibling transfer by proof of validity only if it has
> at least two parents with independent validator sets (no two in one
> G_u) and every parent's aggregate commitment contains the lock. A chain
> without two such parents receives sibling transfers through its backbone
> parent, as two lock-based hops.

With the amendment, together with the refund of
[`finding-multihop-unwind.md`](finding-multihop-unwind.md), no honest
chain ever holds an unbacked unit whose provenance avoids the compromised
chain (`ProvenanceContained`). Damage then neither starts nor travels
outside the governance group (`GroupContained`, `CirculationContained`).
This holds with no compromise and with any one chain compromised, on
`dag5` (`tr_amended`) and `path4` (`tr_amended_path`). Rationale, costs
and alternatives: [`resolutions.md`](resolutions.md), D4.
