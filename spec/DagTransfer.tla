---------------------------- MODULE DagTransfer ----------------------------
(***************************************************************************)
(* Cross-chain transfers in the DAG-based multichain architecture, with    *)
(* the communication modes of the tree-based article it generalises.       *)
(*                                                                         *)
(* Action <-> article mapping ([Tree] = tree-based article, [DAG] = DAG    *)
(* article):                                                               *)
(*   Start      a holder requests a transfer of one unit                   *)
(*   SendHop    the current chain locks the unit (or burns its wrapper)    *)
(*              for the next chain and commits the event to its state      *)
(*              root ([Tree] eqs. 3, 6, 9-12)                              *)
(*   Credit     the next chain validates and mints a wrapper (or releases  *)
(*              escrow); siblings verify against the parent's aggregate    *)
(*              B_t ([Tree] eqs. 7, 8, 13, 14)                             *)
(*   Reject     an honest chain refuses a mint ([Tree] eq. 7, Rejected)    *)
(*   ForgeUnit, ForgeAgg, PovTheft   actions of a compromised chain        *)
(*                                                                         *)
(* Units and provenance: a unit's path <<h, c1, ..., ck>> means it is      *)
(* locked in escrow on h for c1, on c1 for c2, ..., and spendable on ck as *)
(* the nested wrapper Wrap(c_{k-1}, ... Wrap(h, Native(h))). Moving back   *)
(* to path[k-1] burns the wrapper and releases the escrow. Real units      *)
(* cannot be created or duplicated by honest actions; a Fake unit is a     *)
(* wrapper or claim with no escrow behind it and appears only through a    *)
(* compromised chain's actions; fic[f] counts the leading chains of its    *)
(* path whose escrow is fictional, so an honest chain refuses to release   *)
(* escrow it does not hold.                                                *)
(*                                                                         *)
(* Abstractions: fixed topology per behaviour; no time, fees or finality;  *)
(* consensus inside a chain atomic and honest unless the chain is          *)
(* compromised; a receiving chain trusts the sending chain's consensus for *)
(* that chain's own state (lock, burn) and applies its own rules to its    *)
(* own state; Merkle proofs are membership in a committed root; validators *)
(* are abstracted into Spread (who a compromise reaches); one compromised  *)
(* chain c0 per behaviour, chosen at the start.                            *)
(*                                                                         *)
(* Mechanism switches (each mutation is a .cfg, never a code change):      *)
(*   UP, OBSERVERS, VALIDATE, UNWIND, ALLOW_REJECT, COMPROMISE             *)
(***************************************************************************)
EXTENDS Integers, FiniteSets, Sequences, TLC

CONSTANTS
    SCENARIO,       \* "tree3", "path4", "dag5", "gu5"
    UP,             \* "lock": upward transfers locked and validated by the
                    \* parent on its own rules; "pov": the parent applies the
                    \* child's proved state transition to its own state
    OBSERVERS,      \* TRUE: child validators observe the parent, V(c) \cap R(p(c)) = {}
    VALIDATE,       \* "backbone": siblings verified against the backbone
                    \* parent's aggregate; "all_parents": against every parent's;
                    \* "multi_parent": against every parent's, and only by a
                    \* chain with at least two parents (resolution)
    UNWIND,         \* "published": a refusal unlocks only the refused hop;
                    \* "amended": the unit is returned hop by hop to the origin
    ALLOW_REJECT,   \* an honest chain may refuse a mint
    COMPROMISE,     \* candidates for c0, one per behaviour (0 = none); {} = no compromise
    MaxTx,          \* transfers started per behaviour
    MaxForge        \* fake units a compromised chain may create

ASSUME /\ UP \in {"lock", "pov"} /\ OBSERVERS \in BOOLEAN
       /\ VALIDATE \in {"backbone", "all_parents", "multi_parent"}
       /\ UNWIND \in {"published", "amended"}
       /\ ALLOW_REJECT \in BOOLEAN /\ MaxTx \in Nat /\ MaxForge \in Nat

(***************************************************************************)
(* Scenarios. Chains are numbered; names in comments.                      *)
(*   tree3  r=1, a=2, b=3        r->a, r->b                                *)
(*   path4  r=1, a=2, b=3, c=4   r->a->b, r->c                             *)
(*   dag5   r1=1, r2=2, a=3, b=4, c=5   r1->a, r1->b, r2->c;               *)
(*          cross r2->a, r2->b                                             *)
(*   gu5    dag5 with a United Governance Structure {r1, r2}               *)
(***************************************************************************)
NChains == CASE SCENARIO = "tree3" -> 3
             [] SCENARIO = "path4" -> 4
             [] SCENARIO \in {"dag5", "gu5"} -> 5
Chain == 1..NChains

Parent == CASE SCENARIO = "tree3" -> <<0, 1, 1>>
            [] SCENARIO = "path4" -> <<0, 1, 2, 1>>
            [] SCENARIO \in {"dag5", "gu5"} -> <<0, 0, 1, 1, 2>>
Cross == IF SCENARIO \in {"dag5", "gu5"} THEN {<<2, 3>>, <<2, 4>>} ELSE {}
GU    == IF SCENARIO = "gu5" THEN {1, 2} ELSE {}

\* Home[u]: home chain of real unit u
Home == CASE SCENARIO = "tree3" -> <<1, 1, 2>>
          [] SCENARIO = "path4" -> <<3>>
          [] SCENARIO \in {"dag5", "gu5"} -> <<3, 5>>

\* Routes[<<from, to>>]: the chains a transfer visits
Routes ==
    CASE SCENARIO = "tree3" ->
            [p \in {<<1, 2>>, <<1, 3>>, <<2, 3>>, <<3, 2>>, <<2, 1>>, <<3, 1>>} |-> p]
      [] SCENARIO = "path4" ->
            (<<3, 4>> :> <<3, 2, 1, 4>>) @@ (<<4, 3>> :> <<4, 1, 2, 3>>)
      [] SCENARIO \in {"dag5", "gu5"} ->
            (<<3, 4>> :> <<3, 4>>) @@ (<<4, 3>> :> <<4, 3>>)
              @@ (<<5, 3>> :> <<5, 2, 3>>) @@ (<<3, 5>> :> <<3, 2, 5>>)

Real == 1..Len(Home)
Fake == (Len(Home) + 1)..(Len(Home) + MaxForge)
Unit == Real \cup Fake

Children(c)  == {v \in Chain : Parent[v] = c}
AllParents(v) == (IF Parent[v] # 0 THEN {Parent[v]} ELSE {}) \cup {x \in Chain : <<x, v>> \in Cross}
Kids(q)      == Children(q) \cup {v \in Chain : <<q, v>> \in Cross}

HopKind(x, y) ==
    IF Parent[y] = x \/ Parent[x] = y THEN "backbone"
    ELSE IF <<x, y>> \in Cross \/ <<y, x>> \in Cross THEN "cross"
    ELSE IF Parent[x] = Parent[y] /\ Parent[x] # 0 THEN "sibling"
    ELSE "none"

ASSUME \A k \in DOMAIN Routes : \A i \in 1..(Len(Routes[k]) - 1) :
           HopKind(Routes[k][i], Routes[k][i + 1]) # "none"

(***************************************************************************)
(* Who a compromise reaches. Without the observer rule a child's           *)
(* validators vote on the parent (worst case: enough to take it over); a   *)
(* United Governance Structure rotates one validator pool over all its     *)
(* members (worst case: every member).                                     *)
(***************************************************************************)
SpreadStep(S) ==
    S \cup (IF OBSERVERS THEN {} ELSE {Parent[x] : x \in {y \in S : Parent[y] # 0}})
      \cup (IF S \cap GU # {} THEN GU ELSE {})
RECURSIVE Fix(_, _)
Fix(S, k) == IF k = 0 THEN S ELSE Fix(SpreadStep(S), k - 1)
Spread(c) == Fix({c}, NChains)

\* Governance structures containing c: G_d pairs of [Tree] eq. 1 (c, its
\* parent, its children) and any G_u with c.
Gov(c) == {c} \cup (IF Parent[c] # 0 THEN {Parent[c]} ELSE {}) \cup Children(c)
              \cup (IF c \in GU THEN GU ELSE {})

Last(q) == q[Len(q)]
Rev(q)  == [i \in 1..Len(q) |-> q[Len(q) - i + 1]]

VARIABLES
    path,       \* path[u]: provenance and position of unit u (<<>>: unused fake slot)
    out,        \* out[u]: chain the unit is in flight to, 0 if none
    start,      \* start[u]: origin of u's current or last transfer
    req,        \* req[u]: requested target of that transfer
    target,     \* target[u]: chain u is travelling to now (req, or start when
                \* refunding); 0 = no transfer in progress
    rt,         \* rt[u]: route being followed
    pos,        \* pos[u]: index of the current chain in rt[u]
    endAt,      \* endAt[u]: chain where the last transfer ended, 0 if none
    commits,    \* commits[c]: events c committed to its state roots
    forgedAgg,  \* forgedAgg[q]: events a compromised aggregator q invented
    comp,       \* compromised chains
    c0,         \* the chain compromised first, 0 if none
    txs,        \* transfers started
    forged,     \* fake units created
    fic,        \* fic[u]: path[u][1..fic[u]] hold no real escrow for u (0 for real units)
    origin      \* origin[f]: honest chain where fake f first became spendable with a
                \* provenance that avoids every compromised chain; 0 if none

vars == <<path, out, start, req, target, rt, pos, endAt, commits, forgedAgg, comp, c0, txs,
          forged, fic, origin>>

Cur(u)  == Last(path[u])
Avoids(q) == \A i \in 1..Len(q) : q[i] \notin comp
Idle(u) == path[u] # <<>> /\ target[u] = 0 /\ out[u] = 0
IsPop(u, y) == Len(path[u]) > 1 /\ path[u][Len(path[u]) - 1] = y
Event(u, x, y) == [u |-> u, f |-> x, t |-> y, len |-> Len(path[u])]
NextFake == Len(Home) + forged + 1

Init ==
    /\ c0 \in (IF COMPROMISE = {} THEN {0} ELSE COMPROMISE)
    /\ comp = (IF c0 = 0 THEN {} ELSE Spread(c0))
    /\ path = [u \in Unit |-> IF u \in Real THEN <<Home[u]>> ELSE <<>>]
    /\ out = [u \in Unit |-> 0]
    /\ start = [u \in Unit |-> 0]
    /\ req = [u \in Unit |-> 0]
    /\ target = [u \in Unit |-> 0]
    /\ rt = [u \in Unit |-> <<>>]
    /\ pos = [u \in Unit |-> 0]
    /\ endAt = [u \in Unit |-> 0]
    /\ commits = [c \in Chain |-> {}]
    /\ forgedAgg = [c \in Chain |-> {}]
    /\ txs = 0
    /\ forged = 0
    /\ fic = [u \in Unit |-> 0]
    /\ origin = [u \in Unit |-> 0]

Start(u, t) ==
    /\ Idle(u) /\ txs < MaxTx
    /\ <<Cur(u), t>> \in DOMAIN Routes
    /\ start' = [start EXCEPT ![u] = Cur(u)]
    /\ req' = [req EXCEPT ![u] = t]
    /\ target' = [target EXCEPT ![u] = t]
    /\ rt' = [rt EXCEPT ![u] = Routes[<<Cur(u), t>>]]
    /\ pos' = [pos EXCEPT ![u] = 1]
    /\ endAt' = [endAt EXCEPT ![u] = 0]
    /\ txs' = txs + 1
    /\ UNCHANGED <<path, out, commits, forgedAgg, comp, c0, forged, fic, origin>>

SendHop(u) ==
    /\ target[u] # 0 /\ out[u] = 0
    /\ LET x == Cur(u)
           y == rt[u][pos[u] + 1]
       IN  /\ out' = [out EXCEPT ![u] = y]
           /\ commits' = [commits EXCEPT ![x] = @ \cup {Event(u, x, y)}]
    /\ UNCHANGED <<path, start, req, target, rt, pos, endAt, forgedAgg, comp, c0, txs, forged,
                   fic, origin>>

\* Aggregate B_t of parent q: what its children committed, plus, if q is
\* compromised, whatever it invents.
Agg(q) == UNION {commits[k] : k \in Kids(q)} \cup (IF q \in comp THEN forgedAgg[q] ELSE {})
Validators(y) == IF VALIDATE = "backbone" THEN {Parent[y]} ELSE AllParents(y)

\* An honest chain releases escrow only if it holds it (its own rules), and
\* accepts a sibling's lock only if every validating parent's aggregate
\* contains it -- under "multi_parent" only if it has two parents or more.
\* A compromised chain accepts anything.
Accepts(u, x, y) ==
    \/ y \in comp
    \/ /\ IsPop(u, y) => Len(path[u]) - 1 > fic[u]
       /\ HopKind(x, y) = "sibling" =>
              /\ VALIDATE = "multi_parent" => Cardinality(AllParents(y)) >= 2
              /\ \A q \in Validators(y) : Event(u, x, y) \in Agg(q)

Credit(u) ==
    /\ out[u] # 0
    /\ LET x == Cur(u)
           y == out[u]
       IN  /\ Accepts(u, x, y)
           /\ path' = [path EXCEPT ![u] = IF IsPop(u, y) THEN SubSeq(@, 1, Len(@) - 1)
                                                         ELSE Append(@, y)]
           /\ out' = [out EXCEPT ![u] = 0]
           /\ pos' = [pos EXCEPT ![u] = @ + 1]
           /\ IF y = target[u]
              THEN /\ target' = [target EXCEPT ![u] = 0]
                   /\ endAt' = [endAt EXCEPT ![u] = y]
              ELSE UNCHANGED <<target, endAt>>
           /\ origin' = IF u \in Fake /\ origin[u] = 0 /\ Avoids(path'[u]) /\ y \notin comp
                        THEN [origin EXCEPT ![u] = y] ELSE origin
    /\ UNCHANGED <<start, req, rt, commits, forgedAgg, comp, c0, txs, forged, fic>>

\* A lock that only a compromised aggregator claimed (the source's holding is
\* fictional) has nothing behind it on an honest source: the refusal lets
\* the claim lapse instead of unlocking anything.
Reject(u) ==
    /\ ALLOW_REJECT /\ out[u] # 0
    /\ LET x == Cur(u)
           y == out[u]
       IN  /\ y \notin comp
           /\ ~IsPop(u, y)                       \* only a mint can be refused
           /\ out' = [out EXCEPT ![u] = 0]
           /\ IF Len(path[u]) <= fic[u] /\ x \notin comp
              THEN /\ path' = [path EXCEPT ![u] = <<>>]
                   /\ target' = [target EXCEPT ![u] = 0]
                   /\ UNCHANGED <<rt, pos, endAt>>
              ELSE /\ UNCHANGED path
                   /\ IF UNWIND = "amended" /\ x # start[u]
                      THEN /\ target' = [target EXCEPT ![u] = start[u]]
                           /\ rt' = [rt EXCEPT ![u] = Rev(SubSeq(@, 1, pos[u]))]
                           /\ pos' = [pos EXCEPT ![u] = 1]
                           /\ UNCHANGED endAt
                      ELSE /\ target' = [target EXCEPT ![u] = 0]
                           /\ endAt' = [endAt EXCEPT ![u] = x]
                           /\ UNCHANGED <<rt, pos>>
    /\ UNCHANGED <<start, req, commits, forgedAgg, comp, c0, txs, forged, fic, origin>>

(***************************************************************************)
(* Compromised chains                                                      *)
(***************************************************************************)
\* c mints a unit with no escrow behind it on its own ledger: its own
\* native asset beyond supply, or a wrapper claiming a neighbour's lock.
ForgeUnit(c) ==
    /\ forged < MaxForge
    /\ \E p \in {<<c>>} \cup {<<h, c>> : h \in {k \in Chain : HopKind(k, c) # "none"}} :
           /\ path' = [path EXCEPT ![NextFake] = p]
           /\ fic' = [fic EXCEPT ![NextFake] = Len(p) - 1]
    /\ forged' = forged + 1
    /\ UNCHANGED <<out, start, req, target, rt, pos, endAt, commits, forgedAgg, comp, c0, txs,
                   origin>>

\* A compromised aggregator q invents a lock by child x for sibling y. One
\* adversary controls every compromised chain, so the invented lock appears
\* in the aggregate of each of them.
ForgeAgg(q) ==
    /\ forged < MaxForge
    /\ \E x, y \in Kids(q) :
           /\ x # y /\ HopKind(x, y) = "sibling"
           /\ LET f == NextFake IN
              /\ path' = [path EXCEPT ![f] = <<x>>]
              /\ out' = [out EXCEPT ![f] = y]
              /\ start' = [start EXCEPT ![f] = x]
              /\ req' = [req EXCEPT ![f] = y]
              /\ target' = [target EXCEPT ![f] = y]
              /\ rt' = [rt EXCEPT ![f] = <<x, y>>]
              /\ pos' = [pos EXCEPT ![f] = 1]
              /\ forgedAgg' = [c \in Chain |-> IF c \in comp
                                                 THEN forgedAgg[c] \cup {[u |-> f, f |-> x, t |-> y, len |-> 1]}
                                                 ELSE forgedAgg[c]]
              /\ fic' = [fic EXCEPT ![f] = 1]
    /\ forged' = forged + 1
    /\ UNCHANGED <<endAt, commits, comp, c0, txs, origin>>

\* UP = "pov": the parent p applies a proved transition of child c to its
\* own state, so c can have p release a unit p holds in escrow for another
\* link. The unit becomes free on p (taken by c's holders); the wrapper on
\* the other side keeps circulating with nothing behind it (a Fake copy).
PovTheft(c) ==
    /\ UP = "pov" /\ forged < MaxForge /\ Parent[c] # 0
    /\ \E u \in Real, i \in 1..NChains :
           /\ Idle(u) /\ i < Len(path[u])
           /\ path[u][i] = Parent[c] /\ path[u][i + 1] # c
           /\ path' = [path EXCEPT ![u] = SubSeq(@, 1, i), ![NextFake] = path[u]]
           /\ fic' = [fic EXCEPT ![NextFake] = i]
           /\ origin' = IF Avoids(path[u]) THEN [origin EXCEPT ![NextFake] = Last(path[u])]
                        ELSE origin
    /\ forged' = forged + 1
    /\ UNCHANGED <<out, start, req, target, rt, pos, endAt, commits, forgedAgg, comp, c0, txs>>

Next ==
    \/ \E u \in Unit, t \in Chain : Start(u, t)
    \/ \E u \in Unit : SendHop(u) \/ Credit(u) \/ Reject(u)
    \/ \E c \in comp : ForgeUnit(c) \/ ForgeAgg(c) \/ PovTheft(c)

Fairness == \A u \in Real : WF_vars(SendHop(u)) /\ WF_vars(Credit(u) \/ Reject(u))

Spec == Init /\ [][Next]_vars /\ Fairness

(***************************************************************************)
(* Properties                                                              *)
(***************************************************************************)
TypeOK ==
    /\ path \in [Unit -> Seq(Chain)]
    /\ out \in [Unit -> Chain \cup {0}]
    /\ start \in [Unit -> Chain \cup {0}] /\ req \in [Unit -> Chain \cup {0}]
    /\ target \in [Unit -> Chain \cup {0}] /\ endAt \in [Unit -> Chain \cup {0}]
    /\ comp \subseteq Chain /\ c0 \in Chain \cup {0}
    /\ txs \in 0..MaxTx /\ forged \in 0..MaxForge
    /\ fic \in [Unit -> 0..NChains] /\ origin \in [Unit -> Chain \cup {0}]

\* Supply ([Tree] eq. 5): every real unit exists once, from its home. With
\* units as paths this holds by construction for honest actions; the
\* invariant guards the encoding.
Conservation == \A u \in Real : path[u] # <<>> /\ path[u][1] = Home[u]

\* Backing ([Tree] eqs. 3-4, 8: the bijection phi): without a compromise no
\* wrapper exists without its escrow.
Backed == comp = {} => \A f \in Fake : path[f] = <<>>

\* A transfer ends exactly at its origin or its requested target.
SettlesSafe == \A u \in Real : endAt[u] # 0 => endAt[u] \in {start[u], req[u]}

\* Every transfer ends (honest rows, under Fairness).
Terminates == \A u \in Real : (target[u] # 0) ~> (target[u] = 0)

\* Honest chains holding a unit with nothing behind it whose provenance
\* avoids every compromised chain.
Damaged ==
    {v \in Chain \ comp :
        \E f \in Fake : /\ path[f] # <<>> /\ out[f] = 0 /\ Last(path[f]) = v
                        /\ \A i \in 1..Len(path[f]) : path[f][i] \notin comp}

ProvenanceContained == Damaged = {}

Blast == UNION {Gov(c) : c \in comp}

\* BR = 3 ([DAG] Sect. 3.7, [Tree]): spillover limited to a governance group.
\* The compromise stays in c0's governance structures, and unbacked value is
\* created only on chains in the governance structures of compromised chains.
GroupContained ==
    /\ c0 # 0 => comp \subseteq Gov(c0)
    /\ {origin[f] : f \in Fake} \ {0} \subseteq Blast

\* Characterisation, not claimed: unbacked units also stay inside while they
\* circulate. Their provenance names the chains on their path, not the
\* validator that failed, so honest chains pass them on.
CirculationContained == Damaged \subseteq Blast

(***************************************************************************)
(* Witnesses: each must be violated, so the passing rows are not vacuous.  *)
(***************************************************************************)
NoForgedOnHonest == ~\E f \in Fake : path[f] # <<>> /\ out[f] = 0 /\ Last(path[f]) \notin comp
NoMultiHop  == ~\E u \in Real : endAt[u] # 0 /\ endAt[u] = req[u] /\ Len(rt[u]) >= 4
NoDualValid == ~\E u \in Real : /\ endAt[u] # 0 /\ endAt[u] = req[u]
                                /\ HopKind(start[u], req[u]) = "sibling"
                                /\ Cardinality(AllParents(req[u])) >= 2
NoRefund    == ~\E u \in Real : endAt[u] # 0 /\ endAt[u] = start[u] /\ req[u] # start[u]
NoGuSpread  == c0 # 0 => ~(GU \subseteq comp)
=============================================================================
