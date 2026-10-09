---------------------------- MODULE DagStructure ----------------------------
(***************************************************************************)
(* Structural claims of the DAG article, Sect. 2.1 (coordination           *)
(* hierarchy) and Sect. 2.3 (routing and naming), checked exhaustively     *)
(* over all small systems.                                                 *)
(*                                                                         *)
(* A system is a record [n, par, ex, lev]: chains 1..n, backbone parent    *)
(* par[v] (0 = root, so in-degree <= 1, condition (3)), cross edges ex,    *)
(* and lev, a level function where a claim needs one. Enumerations:        *)
(*   Systems(n)  chains numbered in a topological order (u < v on every    *)
(*               edge). No loss of generality: condition (1) gives every   *)
(*               valid system such an order. Eh and ex are disjoint (2).   *)
(*   Forests(n)  every backbone with in-degree <= 1 and no cycle, chains   *)
(*               numbered arbitrarily (claims about (3) itself).           *)
(*                                                                         *)
(* CHECK selects one claim; its violations are computed in Init and ce     *)
(* holds the smallest one (fewest chains), or None. Pattern of LemmaOne    *)
(* in the RSDP split-brain artifact.                                       *)
(***************************************************************************)
EXTENDS Integers, FiniteSets, Sequences, TLC

CONSTANTS
    MaxN,   \* systems with 1..MaxN chains are enumerated
    CHECK   \* claim to check, see Viol

VARIABLE ce

Max(S) == CHOOSE x \in S : \A y \in S : y <= x
Range(q) == {q[i] : i \in DOMAIN q}
Rev(q) == [i \in 1..Len(q) |-> q[Len(q) - i + 1]]
Pos(q, x) == CHOOSE i \in DOMAIN q : q[i] = x

(***************************************************************************)
(* Enumeration                                                             *)
(***************************************************************************)
Pairs(n) == {<<u, v>> \in (1..n) \X (1..n) : u < v}

Eh(n, par) == {<<par[v], v>> : v \in {w \in 1..n : par[w] # 0}}

RECURSIVE AcyclicOn(_, _)
AcyclicOn(S, R) ==                         \* Kahn: repeatedly remove sources
    IF S = {} THEN TRUE
    ELSE LET src == {v \in S : ~\E u \in S : <<u, v>> \in R}
         IN  src # {} /\ AcyclicOn(S \ src, R)
Acyclic(n, R) == AcyclicOn(1..n, R)

TopoParents(n) == {p \in [1..n -> 0..(n - 1)] : \A v \in 1..n : p[v] < v}

Systems(n) ==
    UNION {{[n |-> n, par |-> p, ex |-> x, lev |-> <<>>] : x \in SUBSET (Pairs(n) \ Eh(n, p))}
           : p \in TopoParents(n)}

AllSystems == UNION {Systems(n) : n \in 1..MaxN}

Forests(n) == {p \in [1..n -> 0..n] : (\A v \in 1..n : p[v] # v) /\ Acyclic(n, Eh(n, p))}

(***************************************************************************)
(* Backbone navigation (bounded by n, so it terminates on any input)       *)
(***************************************************************************)
RECURSIVE Up(_, _, _)
Up(par, v, k) == IF k = 0 \/ par[v] = 0 THEN v ELSE Up(par, par[v], k - 1)
RECURSIVE DepthOf(_, _, _)
DepthOf(par, v, k) == IF k = 0 \/ par[v] = 0 THEN 0 ELSE 1 + DepthOf(par, par[v], k - 1)
RECURSIVE AncSeq(_, _, _)
AncSeq(par, v, k) == IF k = 0 \/ par[v] = 0 THEN <<v>> ELSE <<v>> \o AncSeq(par, par[v], k - 1)

RootOf(n, par, v) == Up(par, v, n)
Roots(n, par)     == {v \in 1..n : par[v] = 0}
Tree(n, par, r)   == {v \in 1..n : RootOf(n, par, v) = r}

\* shorthands on a system s
E(s)          == Eh(s.n, s.par) \cup s.ex
Und(s)        == E(s) \cup {<<e[2], e[1]>> : e \in E(s)}
Rt(s, v)      == RootOf(s.n, s.par, v)
Dp(s, v)      == DepthOf(s.par, v, s.n)
Anc(s, v)     == AncSeq(s.par, v, s.n)       \* <<v, parent, ..., root>>
RootSet(s)    == Roots(s.n, s.par)
Kids(s, v)    == {w \in 1..s.n : s.par[w] = v}

(***************************************************************************)
(* st_forest: (3) in an acyclic G makes H a disjoint union of rooted       *)
(* out-trees: every chain reaches a root, each tree has |tree| - 1         *)
(* backbone edges, and no backbone edge joins two trees.                   *)
(***************************************************************************)
ForestOK(n, p) ==
    /\ \A v \in 1..n : p[RootOf(n, p, v)] = 0
    /\ \A r \in Roots(n, p) :
           Cardinality({e \in Eh(n, p) : e[2] \in Tree(n, p, r)}) = Cardinality(Tree(n, p, r)) - 1
    /\ \A e \in Eh(n, p) : RootOf(n, p, e[1]) = RootOf(n, p, e[2])

(***************************************************************************)
(* st_roles: roles derived from backbone degrees.                          *)
(***************************************************************************)
Bough(s)  == {v \in 1..s.n : Kids(s, v) # {}}
Spring(s) == {v \in 1..s.n : Kids(s, v) = {}}
RolesOK(s) ==
    /\ Bough(s) \cap Spring(s) = {}
    /\ Bough(s) \cup Spring(s) = 1..s.n
    /\ RootSet(s) # {}

(***************************************************************************)
(* st_cross: a cross edge that goes forward in a level function of the     *)
(* backbone cannot close a cycle. Checking the largest forward set Fwd is  *)
(* enough: every admissible Ex is a subset of it, and a subgraph of an     *)
(* acyclic graph is acyclic. Levels range over 0..n-1, which realises      *)
(* every weak order of n chains.                                           *)
(***************************************************************************)
Lev(n, p) == {l \in [1..n -> 0..(n - 1)] : \A e \in Eh(n, p) : l[e[1]] < l[e[2]]}
Fwd(n, p, l) == {<<u, v>> \in (1..n) \X (1..n) : l[u] < l[v]} \ Eh(n, p)
CrossViol(n) ==
    UNION {{[n |-> n, par |-> p, ex |-> Fwd(n, p, l), lev |-> l]
             : l \in {m \in Lev(n, p) : ~Acyclic(n, Eh(n, p) \cup Fwd(n, p, m))}}
           : p \in Forests(n)}

(***************************************************************************)
(* st_layer_*: normalisation (5). Backbone edges go exactly one level      *)
(* down, so a layering is l(v) = off(root of v) + depth(v) for some root   *)
(* offsets; cross edges need l(u) < l(v), i.e. the difference constraint   *)
(* off(Rt v) - off(Rt u) >= depth(u) - depth(v) + 1.                       *)
(*   Layerable  brute force over offsets in 0..Bound. If the constraints   *)
(*              are satisfiable, longest paths from 0 satisfy them; such a *)
(*              path has <= R - 1 edges of weight <= n - R + 1 (a depth is *)
(*              at most n - R), so Bound covers every solution's shape.    *)
(*   Feasible   the amended characterisation: Bellman-Ford longest-path    *)
(*              relaxation converges (no positive cycle among the roots;   *)
(*              a cross edge inside one tree must go strictly deeper).     *)
(***************************************************************************)
Cons(s) == {[a |-> Rt(s, e[1]), b |-> Rt(s, e[2]), w |-> Dp(s, e[1]) - Dp(s, e[2]) + 1] : e \in s.ex}
Relax(s, x) == [r \in RootSet(s) |-> Max({x[r]} \cup {x[c.a] + c.w : c \in {d \in Cons(s) : d.b = r}})]
RECURSIVE Iter(_, _, _)
Iter(s, x, k) == IF k = 0 THEN x ELSE Iter(s, Relax(s, x), k - 1)
Potential(s) == Iter(s, [r \in RootSet(s) |-> 0], Cardinality(RootSet(s)))
Feasible(s) == Relax(s, Potential(s)) = Potential(s)
Lv(s, v) == Potential(s)[Rt(s, v)] + Dp(s, v)

Bound(s) == (Cardinality(RootSet(s)) - 1) * (s.n - Cardinality(RootSet(s)) + 1)
LayeredBy(s, off) == \A e \in s.ex : off[Rt(s, e[1])] + Dp(s, e[1]) < off[Rt(s, e[2])] + Dp(s, e[2])
Layerable(s) == \E off \in [RootSet(s) -> 0..Bound(s)] : LayeredBy(s, off)

(***************************************************************************)
(* st_layer_relaxed: the resolution's normalisation (5'). l(v) is the      *)
(* length of the longest path of G ending at v; every edge, backbone or    *)
(* cross, then goes one or more levels down. Chains are numbered in a      *)
(* topological order, so the recursion only looks at smaller chains.       *)
(***************************************************************************)
LP(s) == LET f[v \in 1..s.n] ==
                 Max({0} \cup {f[u] + 1 : u \in {w \in 1..(v - 1) : <<w, v>> \in E(s)}})
         IN  f
RelaxedOK(s) == LET l == LP(s) IN \A e \in E(s) : l[e[1]] < l[e[2]]

(***************************************************************************)
(* rt_names: structured names (Sect. 2.3). A chain's label is its rank     *)
(* among its siblings (roots are siblings of each other); its name is the  *)
(* labels from its root down. A root directory resolves the first label,   *)
(* each chain resolves a child label.                                      *)
(***************************************************************************)
Sibs(s, v)  == {w \in 1..s.n : s.par[w] = s.par[v]}
Label(s, v) == Cardinality({w \in Sibs(s, v) : w <= v})
RECURSIVE NameOf(_, _, _)
NameOf(s, v, k) ==
    IF k = 0 \/ s.par[v] = 0 THEN <<Label(s, v)>>
    ELSE Append(NameOf(s, s.par[v], k - 1), Label(s, v))
Name(s, v) == NameOf(s, v, s.n)
DirRoot(s, l) == IF \E r \in RootSet(s) : Label(s, r) = l
                 THEN CHOOSE r \in RootSet(s) : Label(s, r) = l ELSE 0
Child(s, v, l) == IF \E w \in Kids(s, v) : Label(s, w) = l
                  THEN CHOOSE w \in Kids(s, v) : Label(s, w) = l ELSE 0
RECURSIVE Walk(_, _, _, _)
Walk(s, cur, nm, i) ==
    IF cur = 0 \/ i > Len(nm) THEN cur ELSE Walk(s, Child(s, cur, nm[i]), nm, i + 1)
Resolve(s, nm) == Walk(s, DirRoot(s, nm[1]), nm, 2)
NamesOK(s) ==
    /\ \A v \in 1..s.n : Resolve(s, Name(s, v)) = v /\ Len(Name(s, v)) = Dp(s, v) + 1
    /\ \A v, w \in 1..s.n : v # w => Name(s, v) # Name(s, w)

(***************************************************************************)
(* rt_reach_*: transfer paths. Published: any link may be used (backbone   *)
(* hop or cross-edge governance link, either direction); a path exists    *)
(* iff the undirected graph of E is connected. Amended: under the added    *)
(* connectivity condition, the name-based route -- climb to the lowest     *)
(* common ancestor inside a tree, cross between trees over a cross edge    *)
(* chosen on a shortest sequence of trees -- reaches every chain over      *)
(* existing links.                                                         *)
(***************************************************************************)
RECURSIVE ReachFrom(_, _, _)
ReachFrom(R, S, k) == IF k = 0 THEN S ELSE ReachFrom(R, S \cup {e[2] : e \in {f \in R : f[1] \in S}}, k - 1)
Connected(s) == ReachFrom(Und(s), {1}, s.n) = 1..s.n

LCA(s, u, v) ==
    LET C == Range(Anc(s, u)) \cap Range(Anc(s, v))
    IN  CHOOSE a \in C : \A b \in C : Dp(s, b) <= Dp(s, a)
InTree(s, u, v) ==
    LET a == LCA(s, u, v)
    IN  SubSeq(Anc(s, u), 1, Pos(Anc(s, u), a))
          \o Tail(Rev(SubSeq(Anc(s, v), 1, Pos(Anc(s, v), a))))

TAdj(s) == {<<Rt(s, e[1]), Rt(s, e[2])>> : e \in s.ex} \cup {<<Rt(s, e[2]), Rt(s, e[1])>> : e \in s.ex}
RECURSIVE BFS(_, _, _, _)
BFS(adj, pred, front, k) ==
    IF k = 0 \/ front = {} THEN pred
    ELSE LET new == {y \in {e[2] : e \in {f \in adj : f[1] \in front}} : y \notin DOMAIN pred}
             np  == [y \in DOMAIN pred \cup new |->
                       IF y \in DOMAIN pred THEN pred[y] ELSE CHOOSE x \in front : <<x, y>> \in adj]
         IN  BFS(adj, np, new, k - 1)
RECURSIVE PathBack(_, _, _, _)
PathBack(pred, src, y, k) == IF y = src \/ k = 0 THEN <<y>> ELSE Append(PathBack(pred, src, pred[y], k - 1), y)
TreeRoute(s, r1, r2) ==
    LET pred == BFS(TAdj(s), [x \in {r1} |-> r1], {r1}, s.n)
    IN  IF r2 \in DOMAIN pred THEN PathBack(pred, r1, r2, s.n) ELSE <<>>
Gate(s, r1, r2) ==
    CHOOSE g \in {e \in s.ex : Rt(s, e[1]) = r1 /\ Rt(s, e[2]) = r2}
                 \cup {<<e[2], e[1]>> : e \in {f \in s.ex : Rt(s, f[1]) = r2 /\ Rt(s, f[2]) = r1}}
               : TRUE
RECURSIVE Hops(_, _, _, _)
Hops(s, x, ts, v) ==
    IF Len(ts) = 1 THEN InTree(s, x, v)
    ELSE LET g == Gate(s, ts[1], ts[2]) IN InTree(s, x, g[1]) \o Hops(s, g[2], Tail(ts), v)
NameRoute(s, u, v) ==
    LET ts == TreeRoute(s, Rt(s, u), Rt(s, v)) IN IF ts = <<>> THEN <<>> ELSE Hops(s, u, ts, v)
RouteOK(s, u, v) ==
    LET q == NameRoute(s, u, v)
    IN  /\ q # <<>> /\ q[1] = u /\ q[Len(q)] = v
        /\ \A i \in 1..(Len(q) - 1) : <<q[i], q[i + 1]>> \in Und(s)

(***************************************************************************)
(* Claims                                                                  *)
(***************************************************************************)
Viol ==
    CASE CHECK = "st_forest" ->
            UNION {{[n |-> n, par |-> p, ex |-> {}, lev |-> <<>>] : p \in {q \in Forests(n) : ~ForestOK(n, q)}}
                   : n \in 1..MaxN}
      [] CHECK = "st_roles"     -> {s \in AllSystems : ~RolesOK(s)}
      [] CHECK = "st_cross"     -> UNION {CrossViol(n) : n \in 1..MaxN}
      [] CHECK = "st_layer_pub" -> {s \in AllSystems : ~Layerable(s)}
      [] CHECK = "st_layer_amd" -> {s \in AllSystems : Feasible(s) # Layerable(s)}
      [] CHECK = "st_layer_relaxed" -> {s \in AllSystems : ~RelaxedOK(s)}
      [] CHECK = "rt_names"     -> {s \in AllSystems : ~NamesOK(s)}
      [] CHECK = "rt_reach_pub" -> {s \in AllSystems : ~Connected(s)}
      [] CHECK = "rt_reach_amd" ->
            {s \in AllSystems : Connected(s) /\ \E u, v \in 1..s.n : u # v /\ ~RouteOK(s, u, v)}
      \* witnesses: the enumeration contains the cases the claims are about
      [] CHECK = "ws_multiroot" ->
            {s \in AllSystems : Cardinality(RootSet(s)) >= 2 /\ \E e \in s.ex : Rt(s, e[1]) # Rt(s, e[2])}
      [] CHECK = "ws_crossskip" ->
            {s \in AllSystems : Feasible(s) /\ \E e \in s.ex : Lv(s, e[2]) - Lv(s, e[1]) >= 2}
      [] CHECK = "ws_longbackbone" ->
            {s \in AllSystems : \E e \in Eh(s.n, s.par) : LP(s)[e[2]] - LP(s)[e[1]] >= 2}

None == [n |-> 0, par |-> <<>>, ex |-> {}, lev |-> <<>>]

Init ==
    LET V == Viol
    IN  /\ PrintT(<<CHECK, "violations", Cardinality(V)>>)
        /\ ce = IF V = {} THEN None ELSE CHOOSE v \in V : \A w \in V : v.n <= w.n

Spec == Init /\ [][UNCHANGED ce]_ce

NoViolation == ce = None
=============================================================================
