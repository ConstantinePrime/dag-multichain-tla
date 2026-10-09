# Finding: a refused multi-hop transfer is stranded on an intermediate chain

Verdict: **Gap** in [Tree] (communication between remote branches), which
[DAG] inherits. Rows `tr_unwind_pub` (violated) and `tr_unwind_amd` (holds)
of `spec/DagTransfer.tla`.

## The published text

[Tree] describes multi-hop transfers between distant branches as a sequence
of parent–child hops, each recorded on the intermediate chain ("transactions
must be recorded on every intermediary blockchain"), and parent–child
transfers as lock-and-mint with the receiving chain's verdict
Validate: M × R → {Accepted, Rejected} (eq. 7). It does not say what
happens to the earlier hops of a multi-hop transfer when a later hop is
rejected. The literal reading applies the single-hop outcome: the refused
hop is unlocked on its source, and the transfer ends there.

## Counterexample

Scenario `path4`: r = 1, a = 2, b = 3, c = 4, backbone r → a → b and
r → c. A unit of b's asset travels b → a → r → c. Full trace:
`traces/tr_unwind_pub.trace.txt`.

| State | Action | path of the unit | out | endAt | Comment |
|---|---|---|---|---|---|
| 1 | Init | ⟨3⟩ | 0 | 0 | unit at its home b |
| 2 | Start | ⟨3⟩ | 0 | 0 | transfer b → c requested |
| 3 | SendHop | ⟨3⟩ | 2 | 0 | b locks the unit for a |
| 4 | Credit | ⟨3, 2⟩ | 0 | 0 | a mints Wrap(b, ·) |
| 5 | SendHop | ⟨3, 2⟩ | 1 | 0 | a locks the wrapper for r |
| 6 | Reject | ⟨3, 2⟩ | 0 | 2 | r refuses; the transfer ends on a |

`SettlesSafe` — a transfer ends at its origin or its requested target — is
violated: the unit is neither at b, where the sender holds it, nor at c,
where the recipient expects it, but on the intermediate chain a, as a
wrapper the sender did not ask for.

## Proposed amendment

On refusal, return the unit hop by hop to the origin: each previous hop
burns its wrapper and the hop before releases its escrow, as IBC does with
acknowledgements. `tr_unwind_amd` checks that every transfer then ends at
its origin or its target (`SettlesSafe`), that every transfer ends
(`Terminates`, under weak fairness), and `Conservation`; witness
`wt_refund` shows a refund reaching the origin. `tr_amended_path` checks
the same with any one chain compromised, together with the containment
amendment of [`finding-containment.md`](finding-containment.md). Timeouts,
alternatives and cost: [`resolutions.md`](resolutions.md), D3.
