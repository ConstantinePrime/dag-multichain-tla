# Resolutions of the findings

For each finding of this artifact, this document gives the amendment to
the architecture: the amended rule in the notation of [DAG], why it was
chosen over the alternatives, what it costs, and what the model checks.
The articles and the finding documents stay as published. The
dissertation presents the amended architecture and cites this document,
and the rows named in it, as the analysis behind the amendments.

Each resolution has a status:

- **Checked** — the rows hold with the resolution in place, and a
  mutation row shows what fails without it, within the bounds of
  [`model.md`](model.md);
- **Argued** — the proof is given here and is not model-checked.

## Summary

| | Finding | Verdict | Resolution | Rows | Status |
|---|---|---|---|---|---|
| D1 | Layering (5) is not always achievable | Defect | (5′): longest-path levels; (5) only under an exact condition | `st_layer_pub`, `st_layer_amd`, `st_layer_relaxed`, `ws_longbackbone` | Checked |
| D2 | Nothing ensures that chains can reach each other | Gap | (6) connectivity; the root directory publishes the links between trees; an admission rule | `rt_reach_pub`, `rt_reach_amd`, `rt_names` | Checked; admission rule argued |
| D3 | A refused multi-hop transfer is stranded | Gap | refund hop by hop, also on timeout | `tr_unwind_pub`, `tr_unwind_amd`, `wt_refund`, `tr_amended_path` | Checked |
| D4 | Unbacked value leaves the governance group (BR = 3) | Gap | sibling transfers confirmed by every parent of a chain with two independent parents | `tr_valid_circ`, `tr_multi_all`, `tr_multi_gu`, `tr_valid_all`, `tr_amended`, `tr_amended_path` | Checked |
| D5 | A shared validator pool widens the blast radius | Characterisation | BR stated per pool; a pool counts as one parent in D4 | `tr_gu_spread`, `wt_gu_member`, `tr_multi_gu` | Checked |

Two [Tree] mechanisms are confirmed as necessary and kept unchanged:
upward transfers lock rather than use proof of validity (`tr_up_pov` /
`tr_up_lock`), and child validators only observe their parent
(`tr_obs_off` / `tr_obs_on`). `tr_amended` and `tr_amended_path` check the
resolved transfer rules together, with every resolution on, both with no
compromise and with any one chain compromised.

## D1. Layering

**Finding** ([`finding-layering.md`](finding-layering.md)). 118 of the 508
systems with up to four chains satisfy (1)–(4) but admit no level function
with (5); the smallest has three chains. In particular, a cross edge
between two siblings can never be layered, although sibling communication
is the dominant mode in [DAG] §3.7.

**Resolution.** Condition (5) is replaced by

> **(5′) Layering (normalisation).** ℓ(v) is the number of edges of a
> longest directed path of G ending at v. Every edge then goes one or
> more levels down: E = Eₕ ∪ Eₓ ⊆ ⋃_{i<j} L_i × L_j.

and the stronger form is kept as a characterisation:

> (5) holds — backbone edges exactly one level down — iff the difference
> constraints off(r(v)) − off(r(u)) ≥ depth(u) − depth(v) + 1, one per
> cross edge (u, v), are satisfiable over the roots. Here r(v) is the root
> of v's backbone tree and depth(v) is v's distance from it. In
> particular, a cross edge inside one backbone tree must go strictly
> deeper.

The backbone depth, which naming (§2.3) and the governance structures
(§2.2) use, is a different function from ℓ. It is always defined, but it
is not a level function: a cross edge between siblings joins two chains of
equal depth.

**Why (5′) always holds** (the proof the article's "always achievable"
needs). Let (u, v) ∈ E. A longest path ending at u, extended by (u, v),
is a path ending at v, so ℓ(v) ≥ ℓ(u) + 1. Hence ℓ is a strict
topological ranking (1), and every edge goes at least one level down,
which gives (4) and (5′). This is the longest-path layering of the
Sugiyama method [Sugiyama 1981]. Layered drawings of general DAGs draw a
backbone edge that spans several levels through dummy points, one per
level.

**Alternatives.**

- *Keep (5) as a requirement.* The condition above would then become part
  of validity, and it forbids cross edges between siblings, the case §3.7
  relies on.
- *Drop (5) without a replacement.* This leaves the layered diagrams of
  [DAG] undefined.

(5′) keeps the diagrams at no cost. No other definition or claim of [DAG]
uses (5): roles, G_d, G_u and names are defined from p(v) and Eₕ.

**Checked.**

- `st_layer_relaxed`: (5′) holds on all 23,548 systems with up to five
  chains.
- `ws_longbackbone`: the relaxation is used. In 11,334 of those systems a
  backbone edge spans two levels or more.
- `st_layer_pub`: the published claim fails.
- `st_layer_amd`: the exact condition agrees with a brute-force search on
  all 508 systems with up to four chains.

## D2. Connectivity and routing

**Finding** ([`finding-connectivity.md`](finding-connectivity.md)). In
2,627 of the 23,548 systems with up to five chains, some two chains have
no path between them, even if every edge may be used in either direction.
The smallest is two isolated roots. Multiple roots remove the guarantee
that the tree's trunk gave, and nothing replaces it.

**Resolution.**

> **(6) Connectivity.** The underlying undirected graph of G is connected.
> Equivalently, the *tree graph* T is connected: its nodes are the roots
> R, and it joins r and r′ when a cross edge joins their backbone trees.

The routing of §2.3 is completed accordingly:

- The root directory records T, and for each edge of T one cross edge
  that realises it, its *gate*. The root directory is the root-level DNS
  role of §2.3, kept off-chain or on a separate chain.
- A transfer between two chains of one backbone tree climbs to their
  lowest common ancestor and descends.
- Any other transfer follows a shortest path of T, entering each next tree
  through its gate.

Growth keeps (6) by an admission rule:

> A new chain joins either as a backbone child of an existing chain, or as
> a new root together with at least one cross edge to an existing chain. A
> cross edge is removed only if G stays connected without it.

*Argued.* Adding a vertex together with an edge to a connected graph
leaves it connected, and removal is allowed only when it does too. So
every system built by the rule satisfies (6).

**Alternatives.** A global root chain linked to every tree would also
connect the system, but it restores the trunk that [DAG] set out to remove
(CC = 4 in §3.7 would drop). (6) is the weakest condition under which
every pair of chains can communicate, because without it some pair has no
path at all (`rt_reach_pub`). It adds no hub. The directory holds |R|
roots and the edges of T, and [DAG] §2.3 already expects few roots.

**Checked.**

- `rt_reach_pub`: the published rules fail.
- `rt_reach_amd`: on every system with up to five chains that satisfies
  (6), the name-based route above joins every pair of chains over existing
  edges.
- `rt_names`: names are unique and resolve in depth + 1 labels on every
  system.

## D3. Multi-hop transfers

**Finding** ([`finding-multihop-unwind.md`](finding-multihop-unwind.md)).
[Tree] defines the outcome of one hop (eq. 7: Accepted or Rejected) but
not what happens to the earlier hops when a later hop is refused. Read
literally, the refused hop is unlocked and the transfer ends. The unit is
then left on an intermediate chain, as a wrapper the sender did not ask
for (`tr_unwind_pub`, six states).

**Resolution.**

> A transfer along c₀ → c₁ → … → c_k is refunded when the hop into
> c_{i+1} is refused, or is not credited before its timeout. c_i releases
> the unit it locked for c_{i+1}, burns its wrapper and proves the burn to
> c_{i−1}, which releases its escrow, and so on back to c₀. The transfer
> then ends at its origin. A chain may refuse to mint, but never to
> release escrow it holds against a proved burn.

This is the refund of IBC token transfers [ICS-20], where a transfer that
times out or is acknowledged with an error is refunded to its sender,
applied at every hop of the route.

**Alternatives.**

- *An atomic multi-hop transfer* (two-phase commit along the route, or
  hash-time-locked hops) never exposes an intermediate outcome. But every
  hop holds its lock until the end-to-end decision, and a coordinator or a
  hashlock with nested timeouts is needed. [DAG] §3.7 expects multi-hop
  transfers to be rare, so the refund is the cheaper fit. Atomicity would
  be the choice for frequent multi-hop traffic.
- *Leaving the wrapper on the intermediate chain* for the sender to redeem
  gives the sender an asset on a chain it did not choose. That is the
  failure itself.

**Cost.** Only refused transfers pay. A refusal after i completed hops
adds 2i + 1 records: the release of the refused hop, then a burn and a
release for each completed hop.

**Liveness.** In the model, refusal does not depend on whether
confirmations have arrived, so it also stands for a timeout. `Terminates`
therefore covers a hop whose credit never becomes possible.

**Checked.**

- `tr_unwind_pub`: the published reading fails.
- `tr_unwind_amd`: every transfer ends at its origin or its target
  (`SettlesSafe`), every transfer ends (`Terminates`), and supply is
  conserved.
- `wt_refund`: a refund does reach the origin (witness).
- `tr_amended_path`: the same, with D4, on a three-hop route with no
  compromise or any one chain compromised.

## D4. Containment of damage (BR = 3)

**Finding** ([`finding-containment.md`](finding-containment.md)).

- With sibling transfers verified against the backbone parent alone, a
  compromised parent invents a lock in its aggregate. The sibling mints an
  unbacked wrapper whose provenance names only honest chains, and passes
  it over a cross edge to a chain outside the governance group
  (`tr_valid_circ`).
- The unbacked value still originates inside the group (`tr_valid_group`
  holds). So BR = 3, "spillover limited to a governance group", holds for
  where damage starts but not for where it goes.
- Requiring every parent's confirmation is not enough when a chain's only
  parent is compromised (`tr_multi_all`), or when its two parents share a
  validator pool (`tr_multi_gu`).

**Resolution.**

> A chain v credits a sibling transfer by proof of validity only if
> (a) v has at least two parents in G — its backbone parent and its cross
> parents — whose validator sets are independent (no two of them in one
> G_u), and (b) the aggregate commitment B_t of every parent of v contains
> the lock. A chain without two independent parents receives sibling
> transfers through its backbone parent, as two lock-based hops that the
> parent validates on its own rules ([Tree] eqs. 3–8).

**Why it contains the damage.** One compromised chain can invent a lock
only in aggregates it controls. Under (a) and (b), the aggregate of an
honest parent lacks the invented lock, so the credit fails. Unbacked value
can then exist only on the compromised chain's own ledger, or as wrappers
of its assets, whose provenance names it (`ProvenanceContained`). Such
units lose their value in every multichain system: [DAG] §3.4 scores
Cosmos BR = 5 although IBC vouchers of a compromised chain become
worthless. The model therefore counts as damage only units whose
provenance avoids every compromised chain, and D4 removes those
altogether.

**Alternatives.**

- *Restate BR = 3 as a property of origin only.* This is true
  (`tr_valid_group`) but weak: honest chains downstream cannot tell the
  unbacked wrapper from a backed one.
- *Record the confirming parent in the wrapper's provenance*
  (Wrap(x via q, ·)). This makes a forged credit attributable once the
  compromise is detected, without a second parent. It does not prevent
  the credit and depends on detection. It complements D4 and is not
  checked.
- *A threshold instead of every parent.* k-of-n confirmations with
  k ≥ 2 still stop a single compromised parent, and they tolerate n − k
  unavailable parents. (b) is the case k = n, which the model checks; the
  threshold is argued.

**Cost.** A sibling credit waits for the slowest parent's commitment
instead of one, and each extra parent records the lock in its aggregate.
A chain with one parent pays two lock-based hops for a sibling transfer
instead of one proof-of-validity transfer. A parent that withholds its
confirmation stalls the credit. The receiver then refuses after its
timeout, and D3 refunds the transfer (`Terminates` in `tr_amended`).

**Effect on the scores of [DAG] §3.7.**

- D4 is the concrete form of SS = 3's "additional shared security option
  through cross-connections".
- BR = 3 holds in the damage sense for transfers made under D4.
- The latency and cost figures, which assume one parent, apply to chains
  with two parents only if their parents commit at similar intervals.

**Checked.**

- `tr_valid_circ`: backbone parent only — violated.
- `tr_multi_all`: every parent, but one parent only — violated.
- `tr_multi_gu`: two parents in one pool — violated.
- `tr_valid_all`: `dag5`, every parent — holds.
- `tr_amended` (`dag5`) and `tr_amended_path` (`path4`): every resolution
  on, with no compromise or any one chain compromised. `Conservation`,
  `Backed`, `SettlesSafe`, `ProvenanceContained`, `GroupContained`,
  `CirculationContained` and `Terminates` all hold.

## D5. Shared validator pools

**Finding.** A United Governance Structure rotates one validator pool over
its members, so a compromise of the pool reaches every member
(`wt_gu_member`). The blast radius is the members together with their
parents and children (`tr_gu_spread`). The pool lowers the probability of
a 51 % attack ([DAG] §2.2), which TLC cannot measure.

**Resolution.**

- BR is stated per pool: a compromise inside a G_u spreads to the
  governance structures of every member. That is still "a governance
  group", because G_u is one, so BR = 3 holds with Gov(c) including the
  G_u of c (`tr_gu_spread`).
- For D4, members of one G_u count as one parent (`tr_multi_gu`). A chain
  that relies on D4 takes its parents from different pools.
- The pool trades a wider blast radius for a lower probability of
  compromise. The dissertation should present the two together.

**Checked.**

- `tr_gu_spread`: holds.
- `wt_gu_member`: the compromise does reach the other member (witness).
- `tr_multi_gu`: two parents in one pool fail D4's condition.

## The resolved architecture

**Validity.** A quadruple (V, Eₕ, Eₓ, ℓ) is a valid DAG-multichain
architecture iff:

1. DAG: G = (V, E), E = Eₕ ∪̇ Eₓ, is acyclic, and (u, v) ∈ E ⇒ ℓ(u) < ℓ(v).
2. Partition: Eₕ ∩ Eₓ = ∅.
3. Backbone forest: deg⁻_{Eₕ}(v) ≤ 1 for all v.
4. Cross-edge forwardness: (u, v) ∈ Eₓ ⇒ ℓ(u) < ℓ(v).
5. (5′) Layering (normalisation, always achievable): ℓ is the longest-path
   ranking. The strictly layered form (5) exists iff the condition of D1
   holds.
6. Connectivity: the underlying undirected graph of G is connected.

**Growth.** Chains are admitted by the rule of D2.

**Naming and routing.** Names are as in [DAG] §2.3. The root directory
holds the roots, T and the gates, and routes are as in D2.

**Transfers.** The [Tree] modes, with:

- Parent → child and child → parent: lock-based, with the receiving chain
  validating on its own rules. Upward proof of validity is not allowed.
- Child validators observe their parent and do not validate it:
  V(c) ∩ R(p(c)) = ∅.
- Siblings: proof of validity under D4; otherwise through the backbone
  parent.
- Multi-hop: along the route of D2, refunded by D3 when refused.

**Containment.** Against one compromised chain, or one compromised pool:

- the compromise stays within the governance structures of the
  compromised chains;
- unbacked value is created only there;
- every unbacked unit an honest chain holds names a compromised chain in
  its provenance.

## What the resolutions do not cover

- **Bounds.**
  - Structure is checked exhaustively up to five chains (four for
    `st_cross`, `st_layer_pub` and `st_layer_amd`).
  - Transfers are checked on four fixed scenarios, with at most two
    transfers and one forged unit per behaviour.
  - The adversary is one compromised chain, or one compromised pool.
- **Time.** Timeouts (D3, D4) are modelled only as the possibility of
  refusal. Their values, finality and fees are outside the model.
- **Run-time topology.** The admission rule of D2 is argued, not checked.
  Role changes are not modelled.
- **The scoring model of [DAG] §3.** No score changes, but the costs of D3
  and D4 would enter L̄ and C̄ for the transfers they affect.

## For the dissertation

A paragraph that introduces the amendments:

> Further analysis of the architecture with a formal model, checked with
> the TLC model checker (artifact `dag-multichain-tla`, tag `v1`), showed
> that [DAG] needs four amendments:
>
> - the layering normalisation (5) is not always achievable and is
>   replaced by the longest-path layering (5′);
> - the structural rules do not ensure that chains can reach each other,
>   which a connectivity condition (6) restores;
> - a multi-hop transfer refused part-way must be refunded hop by hop;
> - the blast radius BR = 3 holds for damage in circulation only if a
>   sibling transfer is confirmed by every parent of a receiving chain
>   with at least two independent parents.
>
> Each amendment is checked in the model, separately and together, with
> any one chain compromised. Without each of them, the model exhibits a
> counterexample.

## References

- [DAG] M. Kotov, S. Toliupa. *Scaling Multichain Systems using DAG-based
  Architecture*.
- [Tree] M. Kotov. *Tree-based state sharding for scalability and load
  balancing in multichain systems*. Cybersecurity: Education, Science,
  Technique 2(26), 392–408, 2024. doi:10.28925/2663-4023.2024.26.702.
- [Sugiyama 1981] K. Sugiyama, S. Tagawa, M. Toda. *Methods for visual
  understanding of hierarchical system structures*. IEEE Transactions on
  Systems, Man, and Cybernetics 11(2), 109–125, 1981.
- [ICS-20] Interchain Standards, ICS 20: Fungible Token Transfer.
  github.com/cosmos/ibc.
