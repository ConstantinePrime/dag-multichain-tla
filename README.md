# DAG multichain architecture: verification with TLA⁺

This repository uses a computer to check whether a multichain blockchain
architecture behaves as its articles claim. It was built for a PhD
dissertation. It contains:

- a precise model of the architecture, written in TLA⁺;
- 45 checks run with the TLC model checker, each with the result it was
  expected to give and the result it gave;
- for every claim that does not hold as published, a concrete example of
  what goes wrong, a proposed fix, and a check of the fix;
- everything needed to run the checks again and get the same numbers.

The two articles:

- **[DAG]** M. Kotov, S. Toliupa, *Scaling Multichain Systems using
  DAG-based Architecture*. This is the article being checked.
- **[Tree]** M. Kotov, *Tree-based state sharding for scalability and load
  balancing in multichain systems*, Cybersecurity: Education, Science,
  Technique 2(26), 392–408, 2024, doi:10.28925/2663-4023.2024.26.702. This
  is the earlier, tree-shaped architecture that [DAG] extends. [DAG] reuses
  its rules for moving assets between chains, so those rules are modelled
  here too.

Section and equation numbers below refer to these articles.

## Contents

1. [The results at a glance](#1-the-results-at-a-glance)
2. [Background](#2-background): the architecture, model checking, the
   kinds of check
3. [What was checked, and what came out](#3-what-was-checked-and-what-came-out)
4. [What these checks do not cover](#4-what-these-checks-do-not-cover)
5. [Running the checks yourself](#5-running-the-checks-yourself)
6. [Repository layout and further reading](#6-repository-layout-and-further-reading)
7. [Citing](#7-citing)

## 1. The results at a glance

All 45 checks gave the result they were expected to give.

**What holds as published**

- The structural rules of [DAG] §2.1 have the consequences the article
  states: the backbone splits into separate trees, every chain has a
  well-defined role, and cross edges never create a cycle. This was checked
  on every possible system of up to five chains.
- Chain names (§2.3) are unique, and every name leads to its chain.
- When no chain is attacked, transfers never create or lose assets, and
  every transfer finishes either where it started or where it was sent.

**What does not hold as published: four findings**

| # | Finding | Kind | In one sentence |
|---|---|---|---|
| 1 | Layering | Defect | The article says every system can be arranged in neat layers (condition 5). 118 of the 508 systems with up to four chains cannot. |
| 2 | Connectivity | Gap | Nothing in the rules makes sure two chains can reach each other. Two roots with no link between them form a valid system. |
| 3 | Refused multi-hop transfer | Gap | If a transfer that crosses several chains is refused partway, the asset is left on a chain in the middle. |
| 4 | Containment of damage | Gap | A compromised chain can create fake value that then travels outside its own governance group. The article's security score (BR = 3) rules that out. |

A **Defect** fails under every reasonable reading of the article. A **Gap**
fails when the text is read literally, but works once a missing rule is
added. That missing rule is the proposed fix.

There are also two observations about things the article does not claim:

- Cross edges add security only if every parent of a chain checks its
  incoming transfers.
- A shared pool of validators lowers the chance of a takeover but widens
  the damage when one happens.

**Every finding has a fix, and the fixes were checked together.**
[`docs/resolutions.md`](docs/resolutions.md) gives each fix, why it was
chosen over the alternatives, and what it costs. With all four fixes in
place:

- transfers still never create or lose assets;
- every transfer finishes where it started or where it was sent;
- every transfer finishes, unless a compromised chain is holding the asset;
- no honest chain ever holds fake value that cannot be traced back to the
  compromised chain.

This was checked on four different example systems, both with no attacker
and with each chain in turn under the attacker's control.

## 2. Background

### 2.1 The architecture in brief

A *system* is a set of blockchains, called *chains*, connected by directed
links (*edges*). There are two kinds of edge:

- A **backbone edge** goes from a parent chain to a child chain. Each chain
  has at most one backbone parent (condition 3). Chains without a parent
  are **roots**. A root can have its own tree of descendants, and a system
  may have several roots, unlike the tree architecture, which has exactly
  one.
- A **cross edge** is an extra link. It can connect chains in different
  trees, or add a second parent to a chain.

Every edge must point "downwards": the chains can be given *levels* so
that every edge goes from a lower level to a higher one (conditions 1
and 4). Condition 5 asks for a tidier arrangement: every backbone edge goes
down exactly one level.

A chain's **governance group** is the chain, its backbone parent and its
children. Several chains can also form a **United Governance Structure**
(G_u). They then share one pool of validators, rotated among them.

Assets move between chains in three ways, all taken from [Tree]:

- **Parent ↔ child: lock and mint.** The sending chain locks the asset in
  *escrow*, and the receiving chain issues a wrapped copy, a *wrapper*.
  Sending it back burns the wrapper and unlocks the escrow. Wrappers nest,
  so a wrapper records every chain the asset has passed through. This
  record is the asset's *provenance*.
- **Between siblings (two children of one parent): proof of validity.** The
  sender records the lock. The parent periodically publishes one combined
  commitment of its children's records, called an *aggregate*. The receiver
  checks that the lock appears in that aggregate, then mints the wrapper.
- **Over longer distances: multi-hop.** A sequence of the hops above, each
  recorded on the chain it passes through.

Security is scored in [DAG] §3. The score that matters here is **Blast
Radius (BR)**, the "extent of damage from a compromised domain". [DAG]
gives the architecture BR = 3, which its scale defines as "spillover
limited to a governance group".

### 2.2 Model checking with TLA⁺ and TLC

**TLA⁺** is a language for describing a system as a state machine: a set
of variables, the states the system can start in, and the steps that can
change them.

**TLC**, the model checker, takes a small, concrete instance of such a
model and visits **every** state the system can reach. It checks the
properties you give it in each of those states. Two kinds of property are
used here:

- an **invariant** must be true in every reachable state, for example "no
  honest chain holds a fake asset";
- a **liveness property** says that something eventually happens, for
  example "every transfer finishes".

When a property fails, TLC prints a **counterexample**: the exact sequence
of steps that leads to the failure. You can follow it one step at a time,
which makes a counterexample very strong evidence.

TLC checks small instances exhaustively. It does not prove that a property
holds for systems of every size. "Holds" therefore means "holds in every
case up to the stated size", and each check below states its size.

### 2.3 The two models

- **`spec/DagStructure.tla`, the structure model.** This one has no steps.
  It generates every possible system up to a given number of chains, and
  tests each rule on each system. In effect it is a brute-force proof for
  small sizes. There are 23,548 systems with up to five chains.
  - The chains are numbered so that every edge goes from a smaller number
    to a larger one. A system that can be numbered in several such ways is
    counted once per numbering, so the counts below are of numbered
    systems.
  - When a rule fails, the model reports the smallest system on which it
    fails.
- **`spec/DagTransfer.tla`, the transfer model.** This is a state machine.
  Assets move between chains on four small example systems (section 3.4),
  and an attacker may control one chain. TLC explores every order in which
  transfers, approvals, refusals and attacks can happen.

### 2.4 Checks, and the four kinds of check

A **check** is one TLC run: one model, one set of settings, the properties
to test, and the result expected. The other documents call a check a
*row*, because each is one row of the table in
[`tools/gen_models.py`](tools/gen_models.py). That table generates the
configuration files in `models/` and the list of expected results in
`models/expect.tsv`. [`tools/check.py`](tools/check.py) compares each
TLC output with its expected result.

There are four kinds of check:

| Kind | What it does | Expected result |
|---|---|---|
| **Claim check** | Tests a claim of the article as published. | As claimed, or fails where a finding was made. |
| **Mutation check** | Switches off a mechanism the articles argue for, to show the mechanism matters. | Fails. |
| **Fix check** | Switches the proposed fixes on. | Holds. |
| **Witness check** | Asserts that some interesting event never happens, such as "a refund never reaches the sender". | Fails, which proves the event does happen in that setting. This guards against a check that passes only because nothing interesting ever happens. |

Check names start with the area they belong to: `st_` for structure,
`rt_` for names and routing, `tr_` for transfers, and `ws_` or `wt_` for
witnesses.

Of the 45 checks, 21 are expected to hold and 24 to fail: 4 published
claims that fail (the findings), 5 mutations, and 15 witnesses. All 45
gave their expected result.

## 3. What was checked, and what came out

Each subsection names the article's claim, explains how it was checked,
and gives the result. The check names are listed so you can find their
output in `logs/` and their numbers in [`docs/results.md`](docs/results.md).

### 3.1 The shape of the graph ([DAG] §2.1) — holds

The article states that its conditions have three consequences:

- the backbone edges form a set of separate trees, each with its own root;
- every chain is exactly one of *bough* (has children) or *spring* (has
  none), and there is at least one root;
- cross edges that point downwards can never close a cycle.

All three hold.

| Check | What it tests | Systems checked | Result |
|---|---|---|---|
| `st_forest` | the backbone is a set of separate rooted trees | every backbone of up to 5 chains | holds |
| `st_roles` | bough and spring cover every chain exactly once; a root exists | all 23,548 systems of up to 5 chains | holds |
| `st_cross` | downward cross edges cannot create a cycle | every system and level assignment of up to 4 chains | holds |

### 3.2 Layering ([DAG] §2.1) — Finding 1, Defect

**The claim.** After listing conditions 1–5, the article says that
condition 5, "backbone edges go exactly one level down", "is a convenient
normalization … it's always achievable by strict topological numbering".

**What goes wrong.** It is not always achievable. The smallest
counterexample has three chains:

```
chains 1 and 2 are roots
chain 3 is a backbone child of chain 1
cross edges: 1 → 2 and 2 → 3
```

Condition 5 puts chain 3 exactly one level below chain 1. The cross edges
need level(1) < level(2) < level(3), which puts chain 3 at least two
levels below chain 1. Both cannot hold at once.

There is a second three-chain counterexample, inside a single tree: a
root with two children and a cross edge between the two children.
Condition 5 puts both children on the same level, but the cross edge needs
one below the other.

Of the 508 systems with up to four chains, 118 cannot be laid out as
condition 5 requires: 2 of the 24 with three chains, and 116 of the 480
with four.

**The fix.** Replace condition 5 with a version that always exists. Take
a chain's level to be the length of the longest path of edges leading to
it. Then every edge, backbone or cross, goes down **at least** one level.
A drawing shows a backbone edge that spans several levels as a line
through the levels in between, the standard way to draw layered graphs
(Sugiyama et al., 1981). No other rule in [DAG] depends on condition 5,
so nothing else changes.

For readers who want the strict form, the exact condition under which it
exists is given in [`docs/finding-layering.md`](docs/finding-layering.md)
and checked against a brute-force search.

| Check | What it tests | Result |
|---|---|---|
| `st_layer_pub` | the published claim, on all 508 systems of up to 4 chains | fails, as expected: 118 systems have no strict layering |
| `st_layer_amd` | the exact condition for strict layering agrees with brute force | holds on all 508 |
| `st_layer_relaxed` | the fixed layering exists and every edge goes down | holds on all 23,548 systems of up to 5 chains |
| `ws_longbackbone` | witness: the fix is actually needed | 11,334 systems need a backbone edge spanning two levels or more |

### 3.3 Names and reachability ([DAG] §2.3) — Finding 2, Gap

**Names hold.** A chain's name is the list of labels from its root down to
it, like a domain name. A root directory finds the root, and each chain
finds its child by label. `rt_names` checks, on all 23,548 systems of up
to five chains, that names are unique and that every name leads to its
chain.

**Reachability does not.** The article says the naming system will
"facilitate communication between nodes in distant chains". But nothing
in conditions 1–4 says that all chains are connected. In the tree
architecture every chain descends from one trunk, so any two chains are
connected through it. Allowing several roots removes that guarantee, and
nothing replaces it. The smallest counterexample is two roots with no
edge between them. It is a valid system, and no transfer between the two
roots is possible. 2,627 of the 23,548 systems have at least one pair of
chains with no path between them, even when every edge may be used in
either direction.

**The fix.** Add a sixth condition: **the system is connected.**
Equivalently, the separate backbone trees are linked to one another by
cross edges. The root directory publishes which trees are linked, and
through which cross edge.

- A transfer inside one tree climbs to the two chains' nearest common
  ancestor and goes down.
- A transfer between trees follows the shortest chain of linked trees.

To keep the condition true as the system grows, a new chain is admitted
either as a child of an existing chain or as a new root with at least one
cross edge to the existing system. That this rule preserves connectivity
is argued, not checked.

| Check | What it tests | Result |
|---|---|---|
| `rt_names` | names are unique and resolve | holds on all 23,548 systems |
| `rt_reach_pub` | any two chains can reach each other, as published | fails, as expected: 2,627 systems have unreachable pairs |
| `rt_reach_amd` | with the connectivity condition, the name-based route reaches every chain | holds on every connected system of up to 5 chains |
| `ws_multiroot`, `ws_crossskip` | witnesses: the enumeration contains several roots linked by cross edges, and cross edges that skip levels | both occur (21,581 and 10,147 systems) |

### 3.4 The transfer model

The transfer checks run on four small example systems:

| Name | Chains | Backbone | Cross edges | What it exercises |
|---|---|---|---|---|
| `tree3` | r, a, b | r → a, r → b | none | parent–child and sibling transfers, as in [Tree] |
| `path4` | r, a, b, c | r → a → b, r → c | none | a three-hop transfer b → a → r → c |
| `dag5` | r1, r2, a, b, c | r1 → a, r1 → b, r2 → c | r2 → a, r2 → b | two roots; a and b have a second parent r2; transfers between trees |
| `gu5` | as `dag5` | as `dag5` | as `dag5` | as `dag5`, with r1 and r2 sharing one validator pool |

**The attacker** controls at most one chain, chosen at the start. A
controlled chain can:

- mint assets on its own ledger from nothing;
- claim, in the aggregate it publishes for its children, that a child
  locked an asset it never locked;
- under the alternative rule that [Tree] rejects, make its parent release
  escrow the parent holds for another chain.

One attacker controls every compromised chain, so a lie told by one is
repeated by the others. A compromised chain may also simply stop acting.

**The properties checked:**

| Property | Plain meaning |
|---|---|
| `Conservation` | every real asset exists exactly once. True by the way the model is built; it guards the model itself. |
| `Backed` | with no attacker, no asset lacks its escrow. Also true by construction. |
| `SettlesSafe` | a transfer finishes either where it started or where it was sent. |
| `Terminates` | every transfer finishes, unless a compromised chain holds the asset or is the chain asked to accept it. |
| `ProvenanceContained` | no honest chain holds a fake asset whose provenance names no compromised chain. Such a fake cannot be told apart from a real one. |
| `GroupContained` | BR = 3 for where damage **starts**: the attacker's control stays inside the compromised chain's governance group, and fake value is created only there. |
| `CirculationContained` | BR = 3 for where damage **goes**: every honest chain holding an untraceable fake lies inside that group. |

A fake asset whose provenance passes through the compromised chain is not
counted as damage. It can be traced to that chain, and a compromise
devalues such assets in every multichain system. [DAG] itself still scores
Cosmos BR = 5 although Cosmos has the same effect.

### 3.5 Transfers with no attacker — holds

On `tree3` and `dag5`, with no attacker, every transfer conserves assets,
stays backed, finishes where it started or where it was sent, and does
finish.

| Check | Scenario | Result |
|---|---|---|
| `tr_full_tree3` | `tree3`, no attacker | holds (163 states) |
| `tr_full_dag5` | `dag5`, no attacker | holds (70 states) |
| `wt_tree3`, `wt_dag5` | witnesses: a sibling transfer completes; a transfer between the two trees completes | both occur |

### 3.6 Refused multi-hop transfers — Finding 3, Gap

**The claim.** [Tree] describes how one hop ends: the receiving chain
accepts or rejects (eq. 7). It does not say what happens to the earlier
hops of a multi-hop transfer when a later hop is rejected. Read literally,
only the rejected hop is undone.

**What goes wrong.** In `path4`, an asset of chain b travels
b → a → r → c, and r refuses:

| Step | What happens | Where the asset is |
|---|---|---|
| 1 | the transfer b → c starts | on b |
| 2 | b locks the asset for a | locked on b |
| 3 | a accepts and mints a wrapper | wrapper on a |
| 4 | a locks the wrapper for r | locked on a |
| 5 | r refuses; only this hop is undone | wrapper on a, and the transfer is over |

The asset is neither on b, where the sender had it, nor on c, where the
recipient expected it. It sits on a, the chain in the middle, in a form
the sender never asked for.

**The fix.** When a hop is refused, return the asset hop by hop to where
it started. Each chain burns its wrapper and the chain before releases its
escrow, back to the origin. This is how IBC handles a failed or timed-out
token transfer (ICS-20), applied to every hop. Refusing a hop is also how
a timeout is modelled. Hops on the way back cannot be refused, so a
refund always completes.

| Check | What it tests | Result |
|---|---|---|
| `tr_unwind_pub` | the published rule | fails, as expected (6 states) |
| `tr_unwind_amd` | with the refund: transfers end at origin or target, always finish, conserve assets | holds |
| `wt_multihop`, `wt_refund` | witnesses: a three-hop transfer completes; a refund reaches the origin | both occur |

### 3.7 The tree article's two safeguards — consistent with the model

[Tree] argues for two safeguards, and [DAG] keeps both:

1. **Upward transfers lock, they do not use proof of validity.** Otherwise
   a compromised child "could convince its Bough to illegitimately
   transfer assets".
2. **A child's validators only observe the parent; they do not vote on
   it.** Otherwise a compromised child could take its parent over.

Each was checked with the safeguard off and on:

- With proof of validity upwards (`tr_up_pov`), compromised child a makes
  parent r release the escrow r holds for a's sibling b. b's wrapper is
  left with nothing behind it.
- With locking (`tr_up_lock`), this cannot happen.
- Without the observer rule (`tr_obs_off`), a compromise of b spreads up
  to a and r.
- With the rule (`tr_obs_on`), it does not.

Witnesses `wt_forge` and `wt_obs` show that the attacker's forged assets
do reach honest chains in these two settings, so the passing checks are
not passing for want of an attack.

One caution: the model contains these attacks only because they were
written into it, following [Tree]. These pairs show the model agrees with
[Tree]'s reasoning. They are not independent evidence that the safeguards
are needed.

### 3.8 Containment of damage, BR = 3 — Finding 4, Gap

**The claim.** [DAG] §3.7 gives the architecture "Blast Radius /
Containment (BR = 3) – faults are typically isolated to a subnetwork but
could propagate if happen on local coordination networks". By the scale
in §3.1, score 3 means "spillover limited to a governance group". The same
section says sibling communication works "similar to the Polkadot's
solution", where the receiver checks a lock against the parent's
aggregate. The article does not say whether a sibling transfer needs one
parent's confirmation or several.

**What goes wrong.** In `dag5`, root r1 is compromised, and sibling
transfers are checked against the backbone parent only:

| Step | What happens | Where the fake asset is |
|---|---|---|
| 1 | r1 claims in its aggregate that b locked an asset for a; b did not | in transit to a |
| 2 | a checks r1's aggregate, finds the claimed lock, and mints a wrapper | on a |
| 3 | a's holder sends it to c, through r2 | on a |
| 4 | a locks it for r2 | locked on a |
| 5 | r2 accepts and mints a wrapper of it | on r2 |

r2 now holds an asset with nothing behind it. r2 is outside r1's
governance group, which is r1, a and b. The asset's provenance names only
b, a and r2, all honest, so neither r2 nor anyone after it can tell the
asset is fake.

The fake value is still **created** inside r1's group (`tr_valid_group`
holds). So BR = 3 holds for where damage starts, but not for where it
goes.

The article's qualifying clause, "could propagate", does not change this.
It allows a fault on a coordination chain to spread, but the score itself
sets the limit: a governance group. Damage spreading beyond the group is
what scores 2 and 1 describe.

**Why "every parent confirms" is not enough.** Requiring every parent of
the receiving chain to confirm the lock stops the attack in `dag5`
(`tr_valid_all`): a's second parent, r2, has no such lock in its
aggregate. It fails in two other cases:

- **One parent only** (`tr_multi_all`). In `path4`, siblings a and c have
  a single parent, r. "Every parent" is r alone, and r confirms its own
  lie.
- **Two parents in one pool** (`tr_multi_gu`). In `gu5`, a and b share
  parents r1 and r2, but those parents share one validator pool. A
  compromise of the pool controls both, and both confirm the lie.

**The fix.** Two siblings may use proof of validity only if they share at
least two parents whose validators are independent: not in one pool.
Every one of those shared parents must confirm the lock. Otherwise the
transfer goes through the backbone parent, as two locked hops that the
parent checks against its own records. The sender checks the condition
before choosing the route, so it never starts a transfer the receiver may
not accept.

The price:

- a sibling transfer waits for the slowest of the confirming parents;
- siblings without two independent shared parents pay two hops instead of
  one;
- a compromised shared parent can stall a transfer by withholding its
  confirmation. This is argued, not modelled.

| Check | What it tests | Result |
|---|---|---|
| `tr_valid_backbone` | siblings checked against the backbone parent only | fails, as expected: an honest chain holds an untraceable fake |
| `tr_valid_group` | fake value is only created inside the group | holds |
| `tr_valid_circ` | fake value stays inside the group as it moves | fails, as expected (6 states) |
| `tr_valid_all` | every parent confirms, in `dag5` | holds |
| `tr_multi_all` | every parent confirms, but there is only one parent | fails, as expected |
| `tr_multi_gu` | two shared parents, but in one pool | fails, as expected |
| `wt_dualvalid` | witness: a sibling transfer confirmed by both parents completes | occurs |

### 3.9 Shared validator pools ([DAG] §2.2) — an observation

In a United Governance Structure, one pool of validators is rotated over
all member chains. That makes a takeover less likely, which the article
argues and TLC cannot measure, because TLC has no probabilities. But when
the pool is compromised, every member is compromised
(`wt_gu_member`).

In `gu5`, a compromise of r1 therefore reaches all five chains. Without
the pool it would reach only r1, a and b. `tr_gu_spread` records this. It
cannot fail in `gu5`, where the damage region is the whole system, so it
is a measurement, not a test.

### 3.10 All fixes together — holds

The fix checks switch on the multi-hop refund and the sibling-transfer
rule together, and run on all four example systems. Each run covers no
attacker and, in turn, each single chain under the attacker's control.
Every property in section 3.4 holds.

| Check | Scenario | States explored | Result |
|---|---|---|---|
| `tr_amended` | `dag5`: a and b use proof of validity, confirmed by r1 and r2 | 8,287 | holds |
| `tr_amended_tree` | `tree3`: siblings go through r | 9,714 | holds |
| `tr_amended_gu` | `gu5`: a and b go through r1 | 13,094 | holds |
| `tr_amended_path` | `path4`: refunds along a three-hop route | 2,582 | holds |
| `tr_amended_big` | `dag5` with three transfers and two forged assets | 475,047 | holds |
| `tr_amended_path_big` | `path4` with three transfers and two forged assets | 134,196 | holds |

Each of these has a witness that the interesting events really happen:

| Witness | What it shows happens |
|---|---|
| `wt_amended` | a refund under the fixed rules, on `dag5` |
| `wt_detour` | a sibling transfer completing through the parent, on `tree3` |
| `wt_amended_gu` | the same, on `gu5` |
| `wt_amended_path` | a refund along the three-hop route |

The larger-bound checks contain every behaviour of the smaller ones, so
those witnesses carry over.

## 4. What these checks do not cover

- **Size.**
  - The structure checks cover every system of up to five chains, or four
    for `st_cross`, `st_layer_pub` and `st_layer_amd`.
  - The transfer checks cover four fixed example systems, with at most two
    transfers and one forged asset per run, or three and two in the two
    larger checks. [`docs/model.md`](docs/model.md) explains why these
    sizes cover the claims.
- **The attacker.** At most one compromised chain, or one compromised
  pool.
  - It invents locks but not burns.
  - It does not hide honest records from its aggregate.
  - Both limitations are discussed in [`docs/model.md`](docs/model.md).
- **Time and money.** There are no clocks, fees or finality delays. A
  timeout is modelled only as the possibility of refusing.
- **Growth.** The topology is fixed during a run. The rule for admitting
  new chains (section 3.3) is argued, not checked.
- **The scoring model of [DAG] §3** (the latency, throughput, cost and
  security scores and Table 1) is an assessment method over cited figures.
  It is not behaviour of the system, so it is not checked. The fixes would
  change the latency and cost of the transfers they affect.

## 5. Running the checks yourself

**You need** Java 11 or later, GNU make and Python 3. The first run
downloads TLC (`tla2tools.jar`, release v1.7.4, TLC version 2.19) and
checks that its SHA-256 checksum is the pinned one. Every later run checks
it again before starting TLC.

**Run everything:**

```bash
make all                   # all 45 checks, about 5 minutes
```

The last line printed should be `45/45 rows ok`. `make quick` runs every
check except the two larger-bound ones, 43 checks in about 3 minutes.

**Run one check:**

```bash
make tr_valid_circ         # through make
./run.sh tr_valid_circ     # or directly; also verifies the jar
```

**Check existing results without running TLC:**

```bash
python3 tools/check.py     # compares every log with its expected result
```

For each check this prints `ok` or `DIFF`, the expected and actual result,
the number of states explored, and the run time. It exits with an error
if any result differs, a log is missing, or a log is **stale**. Each log
starts with a line recording the checksums of the model, the configuration
and the TLC jar it was produced with. A log whose inputs have changed
since is reported as stale.

**Where the results are:**

- `logs/<check>.log` is the raw TLC output for each check.
- `traces/` holds the counterexamples the documents cite, copied from the
  logs with `python3 tools/trace.py <check>`.
- [`docs/results.md`](docs/results.md) has the table of every check, with
  states explored, depth and run time.

Runs use one worker thread. That makes counterexamples as short as
possible and the numbers exactly reproducible. `WORKERS=auto make all`
is faster and gives the same verdicts. Checks that hold also give the
same state counts; checks that fail may stop at a different point.

## 6. Repository layout and further reading

| Path | What it is |
|---|---|
| `spec/DagStructure.tla` | the structure model (sections 3.1–3.3) |
| `spec/DagTransfer.tla` | the transfer model (sections 3.4–3.10) |
| `tools/gen_models.py` | the table of all checks; generates `models/` |
| `tools/check.py` | compares results with expectations; `--md` prints the results table |
| `tools/trace.py` | copies a counterexample from a log into `traces/` |
| `models/` | generated TLC configurations and the list of expected results |
| `logs/`, `traces/` | TLC output of the reported runs, and the cited counterexamples |
| `Makefile`, `run.sh` | run checks through make, or one at a time |

| Document | Read it for |
|---|---|
| [`docs/resolutions.md`](docs/resolutions.md) | each fix in the article's notation: why this fix, the alternatives, the cost, the corrected architecture in one place, and a paragraph for the dissertation |
| [`docs/results.md`](docs/results.md) | the full results table, and which witness backs which check |
| [`docs/model.md`](docs/model.md) | exactly what the models contain, what they leave out, and why the sizes are enough |
| [`docs/finding-layering.md`](docs/finding-layering.md) | Finding 1 in full |
| [`docs/finding-connectivity.md`](docs/finding-connectivity.md) | Finding 2 in full |
| [`docs/finding-multihop-unwind.md`](docs/finding-multihop-unwind.md) | Finding 3 in full |
| [`docs/finding-containment.md`](docs/finding-containment.md) | Finding 4 in full |

## 7. Citing

Cite the tag `v1` rather than the `main` branch, so that readers see the
exact models, logs and numbers described here.
