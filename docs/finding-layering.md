# Finding: layering (5) is not always achievable

Verdict: **Defect** in [DAG] §2.1. Rows `st_layer_pub` (violated) and
`st_layer_amd` (holds) of `spec/DagStructure.tla`.

## The published text

[DAG] §2.1 lists five conditions for a valid DAG-multichain architecture and
adds: "(1)–(4) are the essential structural rules and (5) is a convenient
normalization matching layered diagrams; it's always achievable by strict
topological numbering." Condition (5) requires every backbone edge to go
exactly one level down, Eₕ ⊆ ⋃ L_k × L_{k+1}, and every cross edge to go
down one or more levels, Eₓ ⊆ ⋃_{i<j} L_i × L_j.

## Counterexample

`st_layer_pub` enumerates every system with up to four chains (508
topologically numbered systems; see `docs/model.md`) and searches, for each, a level function satisfying (1), (4) and (5). It
finds 118 systems without one, 2 of the 24 with three chains and 116 of the
480 with four. The smallest, recorded in `traces/st_layer_pub.trace.txt`:

```
ce = [n |-> 3, par |-> <<0, 0, 1>>, ex |-> {<<1, 2>>, <<2, 3>>}, lev |-> <<>>]
```

Chains 1 and 2 are roots; chain 3's backbone parent is 1; cross edges
1 → 2 and 2 → 3. Conditions (1)–(4) hold with ℓ = (0, 1, 2). Condition (5)
forces ℓ(3) = ℓ(1) + 1, but the cross edges force ℓ(1) < ℓ(2) < ℓ(3), so
ℓ(3) ≥ ℓ(1) + 2. The other three-chain counterexample is the sibling case:
root r with backbone children a and b and a cross edge a → b, where (5)
forces ℓ(a) = ℓ(b) and the cross edge ℓ(a) < ℓ(b).

The second case shows that the restriction is not an artefact of several
roots: inside one backbone tree, (1)–(4) allow a cross edge between two
chains of equal depth, and (5) never does. More generally, (5) admits a
cross edge inside a tree only if it goes strictly deeper.

## Proposed amendment

Replace (5) with a normalisation that always exists, and keep (5) as a
characterisation:

> (5′) ℓ(v) is the number of edges of a longest path of G ending at v;
> every edge, backbone or cross, goes one or more levels down.
>
> (5) holds iff the constraints off(r(v)) − off(r(u)) ≥
> depth(u) − depth(v) + 1, one per cross edge (u, v), are satisfiable over the root offsets
> (r(v) is the root of v's backbone tree), i.e. iff the constraint graph
> over the roots has no cycle of positive weight. In particular, a cross
> edge inside one backbone tree must go strictly deeper.

`st_layer_relaxed` checks that (5′) holds on all 23,548 systems with up to
five chains, and `ws_longbackbone` that it is used: in 11,334 of them a
backbone edge spans two levels or more. `st_layer_amd` compares the
characterisation of (5) (Bellman–Ford longest-path relaxation over the
roots) with an independent brute-force search over root offsets on all
508 systems with up to four chains, and the two agree on every one. Why
(5′) and not the alternatives: [`resolutions.md`](resolutions.md), D1.
