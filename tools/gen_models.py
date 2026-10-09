#!/usr/bin/env python3
"""Generate models/*.cfg, models/expect.tsv and models/rows.mk from ROWS.

Every configuration is a row of one table, so rows stay comparable: a row
states only what it changes from its module's BASE. Run from anywhere:
    python3 tools/gen_models.py
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..', 'models'))

BASE = {
    'DagStructure': dict(MaxN=5, CHECK=None),
    'DagTransfer': dict(SCENARIO='"tree3"', UP='"lock"', OBSERVERS='TRUE',
                        VALIDATE='"backbone"', UNWIND='"published"',
                        ALLOW_REJECT='FALSE', COMPROMISE='{}', MaxTx=2, MaxForge=1),
}

S, T = 'DagStructure', 'DagTransfer'
HOLDS = 'holds'


def viol(name):
    return 'violated:' + name


# (row, module, overrides, invariants, properties, expected, comment)
ROWS = [
    # --- DagStructure: Sect. 2.1 and 2.3 claims, exhaustive ---
    ('st_forest', S, dict(CHECK='"st_forest"'), ['NoViolation'], [], HOLDS,
     '(3) in an acyclic G: the backbone is a disjoint union of rooted out-trees.'),
    ('st_roles', S, dict(CHECK='"st_roles"'), ['NoViolation'], [], HOLDS,
     'Roles derived from backbone degrees: bough and spring partition V.'),
    ('st_cross', S, dict(CHECK='"st_cross"', MaxN=4), ['NoViolation'], [], HOLDS,
     '(4): cross edges forward in a level function cannot close a cycle.'),
    ('st_layer_pub', S, dict(CHECK='"st_layer_pub"', MaxN=4), ['NoViolation'], [],
     viol('NoViolation'),
     'Published: normalisation (5) is always achievable. Expect a 3-chain counterexample.'),
    ('st_layer_amd', S, dict(CHECK='"st_layer_amd"', MaxN=4), ['NoViolation'], [], HOLDS,
     'Amended: (5) is achievable iff the root-offset difference constraints are\n'
     'satisfiable (Bellman-Ford); checked against brute force over offsets.'),
    ('st_layer_relaxed', S, dict(CHECK='"st_layer_relaxed"'), ['NoViolation'], [], HOLDS,
     'Resolution (5\'): the longest-path ranking puts every edge, backbone or cross,\n'
     'one or more levels down, on every system.'),
    ('rt_names', S, dict(CHECK='"rt_names"'), ['NoViolation'], [], HOLDS,
     'Sect. 2.3: structured names are unique and resolve from the root directory.'),
    ('rt_reach_pub', S, dict(CHECK='"rt_reach_pub"'), ['NoViolation'], [], viol('NoViolation'),
     'Published: any two chains can communicate. (1)-(4) do not require\n'
     'connectivity; expect two isolated roots.'),
    ('rt_reach_amd', S, dict(CHECK='"rt_reach_amd"'), ['NoViolation'], [], HOLDS,
     'Amended: with the underlying graph of E connected, the name-based route\n'
     '(LCA inside a tree, cross edges between trees) reaches every chain.'),
    ('ws_multiroot', S, dict(CHECK='"ws_multiroot"'), ['NoViolation'], [], viol('NoViolation'),
     'Witness: the enumeration has systems with >= 2 roots linked by a cross edge.'),
    ('ws_crossskip', S, dict(CHECK='"ws_crossskip"'), ['NoViolation'], [], viol('NoViolation'),
     'Witness: the enumeration has layered systems whose cross edge skips >= 2 levels.'),
    ('ws_longbackbone', S, dict(CHECK='"ws_longbackbone"'), ['NoViolation'], [],
     viol('NoViolation'),
     'Witness: under (5\') some backbone edge spans >= 2 levels, so the relaxation is used.'),

    # --- DagTransfer: transfers, compromise containment ---
    ('tr_full_tree3', T, {}, ['TypeOK', 'Conservation', 'Backed', 'SettlesSafe'], ['Terminates'],
     HOLDS, 'Full design, tree3, no compromise.'),
    ('tr_full_dag5', T, dict(SCENARIO='"dag5"'),
     ['TypeOK', 'Conservation', 'Backed', 'SettlesSafe'], ['Terminates'], HOLDS,
     'Full design, dag5 (two roots, cross parents, transfer between trees), no compromise.'),
    ('tr_up_pov', T, dict(UP='"pov"', COMPROMISE='{2}'), ['TypeOK', 'GroupContained'], [],
     viol('GroupContained'),
     'Upward proof of validity, a compromised: r releases the escrow it holds for b.'),
    ('tr_up_lock', T, dict(COMPROMISE='{2}'),
     ['TypeOK', 'ProvenanceContained', 'GroupContained'], [], HOLDS,
     'Same as tr_up_pov with lock-based upward transfers.'),
    ('tr_obs_off', T, dict(SCENARIO='"path4"', OBSERVERS='FALSE', COMPROMISE='{3}'),
     ['TypeOK', 'GroupContained'], [], viol('GroupContained'),
     'Child validators vote on the parent: a compromise of b climbs to r.'),
    ('tr_obs_on', T, dict(SCENARIO='"path4"', COMPROMISE='{3}'),
     ['TypeOK', 'ProvenanceContained', 'GroupContained'], [], HOLDS,
     'Same as tr_obs_off with the observer rule.'),
    ('tr_valid_backbone', T, dict(SCENARIO='"dag5"', COMPROMISE='{1}'),
     ['TypeOK', 'ProvenanceContained'], [], viol('ProvenanceContained'),
     'Siblings verified by the backbone parent only; r1 compromised forges an\n'
     'aggregate and b mints a wrapper of a lock a never made.'),
    ('tr_valid_group', T, dict(SCENARIO='"dag5"', COMPROMISE='{1}'),
     ['TypeOK', 'GroupContained'], [], HOLDS,
     'Same scenario: unbacked value is created only inside r1\'s governance\n'
     'group (BR = 3).'),
    ('tr_valid_circ', T, dict(SCENARIO='"dag5"', COMPROMISE='{1}'),
     ['TypeOK', 'CirculationContained'], [], viol('CirculationContained'),
     'Characterisation: the unbacked wrapper minted on b travels on to r2 and c,\n'
     'outside r1\'s governance group; its provenance (a, b) names no failed chain.'),
    ('tr_valid_all', T, dict(SCENARIO='"dag5"', VALIDATE='"all_parents"', COMPROMISE='{1}'),
     ['TypeOK', 'ProvenanceContained', 'GroupContained', 'CirculationContained'], [], HOLDS,
     'Siblings verified by every parent (cross edges add validation).'),
    ('tr_unwind_pub', T, dict(SCENARIO='"path4"', ALLOW_REJECT='TRUE'),
     ['TypeOK', 'SettlesSafe'], [], viol('SettlesSafe'),
     'Published multi-hop: a refusal unlocks only the refused hop; the unit\n'
     'stays on an intermediate chain.'),
    ('tr_unwind_amd', T, dict(SCENARIO='"path4"', UNWIND='"amended"', ALLOW_REJECT='TRUE'),
     ['TypeOK', 'Conservation', 'SettlesSafe'], ['Terminates'], HOLDS,
     'Amended: refusal returns the unit hop by hop to its origin.'),
    # --- the resolved protocol: every amendment on, every single compromise ---
    ('tr_amended', T, dict(SCENARIO='"dag5"', VALIDATE='"multi_parent"', UNWIND='"amended"',
                           ALLOW_REJECT='TRUE', COMPROMISE='{0, 1, 2, 3, 4, 5}'),
     ['TypeOK', 'Conservation', 'Backed', 'SettlesSafe', 'ProvenanceContained', 'GroupContained',
      'CirculationContained'], ['Terminates'], HOLDS,
     'Resolved protocol on dag5: sibling transfers confirmed by every parent of a\n'
     'chain with two parents or more, refund on refusal; no'
     'compromise or any one chain compromised (c0 = 0 means none).'),
    ('tr_amended_path', T, dict(SCENARIO='"path4"', VALIDATE='"multi_parent"',
                                UNWIND='"amended"', ALLOW_REJECT='TRUE',
                                COMPROMISE='{0, 1, 2, 3, 4}'),
     ['TypeOK', 'Conservation', 'Backed', 'SettlesSafe', 'ProvenanceContained', 'GroupContained',
      'CirculationContained'], ['Terminates'], HOLDS,
     'Resolved protocol on path4: refunds along a three-hop route; a and c have one\n'
     'parent each, so a forged sibling lock is refused. No compromise or any one chain.'),
    ('tr_multi_all', T, dict(SCENARIO='"path4"', VALIDATE='"all_parents"', UNWIND='"amended"',
                             ALLOW_REJECT='TRUE', COMPROMISE='{0, 1, 2, 3, 4}'),
     ['TypeOK', 'ProvenanceContained'], [], viol('ProvenanceContained'),
     'Same with every parent confirming but no two-parent condition: r, the only parent\n'
     'of a and c, forges a sibling lock and a credits it.'),
    ('tr_multi_gu', T, dict(SCENARIO='"gu5"', VALIDATE='"multi_parent"', COMPROMISE='{1}'),
     ['TypeOK', 'ProvenanceContained'], [], viol('ProvenanceContained'),
     'Two parents sharing one validator pool (G_u = {r1, r2}) count as one: the\n'
     'compromise reaches both and the forged sibling lock is confirmed.'),
    ('tr_gu_spread', T, dict(SCENARIO='"gu5"', COMPROMISE='{1}'),
     ['TypeOK', 'GroupContained'], [], HOLDS,
     'United Governance Structure {r1, r2}: compromise spreads over the pool,\n'
     'still inside governance groups.'),
    ('wt_forge', T, dict(COMPROMISE='{2}'), ['NoForgedOnHonest'], [], viol('NoForgedOnHonest'),
     'Witness: a forged unit reaches an honest chain.'),
    ('wt_multihop', T, dict(SCENARIO='"path4"'), ['NoMultiHop'], [], viol('NoMultiHop'),
     'Witness: a three-hop transfer completes.'),
    ('wt_dualvalid', T, dict(SCENARIO='"dag5"', VALIDATE='"all_parents"'), ['NoDualValid'], [],
     viol('NoDualValid'), 'Witness: a sibling transfer validated by both parents completes.'),
    ('wt_refund', T, dict(SCENARIO='"path4"', UNWIND='"amended"', ALLOW_REJECT='TRUE'),
     ['NoRefund'], [], viol('NoRefund'), 'Witness: a refund reaches the origin.'),
    ('wt_gu_member', T, dict(SCENARIO='"gu5"', COMPROMISE='{1}'), ['NoGuSpread'], [],
     viol('NoGuSpread'), 'Witness: the compromise reaches the other G_u member.'),
]

# Rows left out of `make quick` (none so far; long rows go here).
SLOW = set()


def cfg_text(module, overrides, invs, props, expected, comment):
    consts = dict(BASE[module])
    consts.update(overrides)
    lines = ['\\* ' + l for l in comment.split('\n')]
    lines.append('\\* Expected: ' + expected)
    lines.append('SPECIFICATION Spec')
    lines.append('CONSTANTS')
    for k, v in consts.items():
        assert v is not None, (module, k)
        lines.append('    %s = %s' % (k, v))
    lines.append('INVARIANTS')
    lines.extend('    ' + i for i in invs)
    if props:
        lines.append('PROPERTIES')
        lines.extend('    ' + p for p in props)
    lines.append('CHECK_DEADLOCK FALSE')
    return '\n'.join(lines) + '\n'


def main():
    os.makedirs(OUT, exist_ok=True)
    names = [r[0] for r in ROWS]
    assert len(names) == len(set(names)), 'duplicate row name'
    expect, mk = [], []
    for name, module, ov, invs, props, exp, comment in ROWS:
        with open(os.path.join(OUT, name + '.cfg'), 'w') as f:
            f.write(cfg_text(module, ov, invs, props, exp, comment))
        expect.append('%s\t%s\t%s' % (name, module, exp))
        mk.append('%s_MODULE = %s' % (name, module))
    with open(os.path.join(OUT, 'expect.tsv'), 'w') as f:
        f.write('\n'.join(expect) + '\n')
    with open(os.path.join(OUT, 'rows.mk'), 'w') as f:
        f.write('# generated by tools/gen_models.py\n')
        f.write('ROWS = %s\n' % ' '.join(names))
        f.write('QUICK = %s\n' % ' '.join(n for n in names if n not in SLOW))
        f.write('\n'.join(mk) + '\n')
    print('wrote %d configurations to %s' % (len(ROWS), OUT))


if __name__ == '__main__':
    main()
