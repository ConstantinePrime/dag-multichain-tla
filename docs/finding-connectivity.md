# Finding: the structural rules do not guarantee that chains can communicate

Verdict: **Gap** in [DAG] §2.1 and §2.3. Rows `rt_reach_pub` (violated) and
`rt_reach_amd` (holds) of `spec/DagStructure.tla`.

## The published text

[DAG] §2.1 calls conditions (1)–(4) "the essential structural rules" and
allows multiple roots ("no global trunk"). §2.3 describes routing: "all
chain A has to know is the root chain address, which then points to its
authoritative record, allowing for recursive traversal of the graph". The
Conclusions state that the routing system will "facilitate communication
between nodes in distant chains".

In the tree architecture every chain is a descendant of the trunk, so any
two chains are connected through their common ancestor. Removing the trunk
removes that guarantee, and no condition replaces it.

## Counterexample

`rt_reach_pub` enumerates every system with up to five chains (23,548
topologically numbered systems) and looks for two chains with no transfer path, where a path may
use any backbone or cross edge in either direction. It finds 2,627; the
smallest (`traces/rt_reach_pub.trace.txt`):

```
ce = [n |-> 2, par |-> <<0, 0>>, ex |-> {}, lev |-> <<>>]
```

Two roots, no edges: valid under (1)–(4), and no transfer is possible
between them. Names still resolve (`rt_names` holds on all 23,548 systems):
the directory says where a chain is, not how to reach it.

## Proposed amendment

Add a sixth condition:

> (6) Connectivity: the underlying undirected graph of E = Eₕ ∪ Eₓ is
> connected — equivalently, the backbone trees are linked by cross edges.

`rt_reach_amd` checks that under (6) the name-based route reaches every
chain from every chain in all 23,548 systems: inside a backbone tree up to
the lowest common ancestor and down; between trees over a cross edge, along
a shortest sequence of trees linked by cross edges; every hop an edge of E.

The root directory publishes the links between trees that this route
uses, and an admission rule for new chains keeps (6) as the system grows:
[`resolutions.md`](resolutions.md), D2.
