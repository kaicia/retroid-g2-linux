#!/usr/bin/env python3
"""Port drivers/interconnect/qcom/cliffs.c (Xiaomi peridot-u-oss, msm-6.1) to the
mainline qcom icc-rpmh framework (sm8550/sm8650 style). The downstream driver is
icc-rpmh EXTENDED with direct QoS-box programming and multi-voter support, which
mainline icc-rpmh does not carry; strip that layer, keep the NoC topology.

Removed (all depend on the downstream-only qnoc-qos.h / extended structs):
  - #include "qnoc-qos.h"
  - VOTER_IDX enum + all *_voters[] arrays + .voters/.num_voters desc fields
  - icc_regmap_config + .config=&icc_regmap_config desc field
  - 32 qcom_icc_qosbox structs + .qosbox node fields
  - .noc_ops node fields (169), .voter_idx bcm fields (46), .perf_mode_mask (2)
Kept: every qcom_icc_node (name/id/channels/buswidth/links), qcom_icc_bcm
(name/enable_mask/nodes), the 14 per-NoC node/bcm arrays + descs, and the
already-mainline probe (qcom_icc_rpmh_probe/remove/sync_state).
Compatibles: qcom,cliffs-<noc> -> qcom,sm8635-<noc-with-hyphens>.
"""
import re

lines = open("cliffs.c" if __import__('os').path.exists("cliffs.c") else "icc-cliffs.c").read().splitlines(keepends=True)
out = []
i, n = 0, len(lines)

def brace_skip(start):
    """return index just past the balanced block starting at line `start`."""
    depth = 0
    j = start
    while j < n:
        depth += lines[j].count('{') - lines[j].count('}')
        j += 1
        if depth == 0:
            break
    return j

drop_line = re.compile(
    r'^\s*\.('
    r'noc_ops|qosbox|voter_idx|perf_mode_mask|voters|num_voters'
    r')\s*=')
compat_re = re.compile(r'"qcom,cliffs-([a-z0-9_]+)"')

while i < n:
    line = lines[i]

    if line.strip() == '#include "qnoc-qos.h"':
        i += 1; continue

    # VOTER_IDX enum block
    if line.rstrip('\n') == 'enum {':
        j = brace_skip(i)
        if any('VOTER_IDX' in lines[k] for k in range(i, j)):
            i = j
            if i < n and lines[i].strip() == '':
                i += 1
            continue

    # icc_regmap_config
    if line.startswith('static const struct regmap_config icc_regmap_config'):
        i = brace_skip(i)
        if i < n and lines[i].strip() == '':
            i += 1
        continue

    # qcom_icc_qosbox structs
    if line.startswith('static struct qcom_icc_qosbox '):
        i = brace_skip(i)
        if i < n and lines[i].strip() == '':
            i += 1
        continue

    # *_voters[] arrays
    if re.match(r'static char \*\w+_voters\[\] = \{', line):
        i = brace_skip(i)
        if i < n and lines[i].strip() == '':
            i += 1
        continue

    # .config = &icc_regmap_config (desc field)
    if re.match(r'^\s*\.config\s*=\s*&icc_regmap_config,', line):
        i += 1; continue

    # per-field line drops
    if drop_line.match(line):
        i += 1; continue

    # compatible rename (underscores -> hyphens in the noc suffix)
    line = compat_re.sub(lambda m: '"qcom,sm8635-' + m.group(1).replace('_', '-') + '"', line)

    out.append(line)
    i += 1

text = ''.join(out)
text = re.sub(r'\n\n\n+', '\n\n', text)
open("icc-sm8635.c", "w").write(text)
print("wrote icc-sm8635.c  lines:", text.count("\n"))
