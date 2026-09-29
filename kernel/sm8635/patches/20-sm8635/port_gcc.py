#!/usr/bin/env python3
"""Port drivers/clk/qcom/gcc-cliffs.c (Xiaomi peridot-u-oss, msm-6.1) to the
mainline qcom clk framework by stripping downstream-only machinery:
  - vdd-level.h include + DEFINE_VDD_REGULATORS + regulators array
  - 36 vdd_data blocks (per-clock voltage scaling)  [brace-matched]
  - .enable_safe_config (downstream clk_rcg2 field)
  - .flags = HW_CLK_CTRL_MODE (downstream rcg struct flag)
  - .flags = CLK_DONT_HOLD_STATE (downstream init flag)
  - .clk_regulators / .num_clk_regulators in qcom_cc_desc
Keeps every real clock/PLL/RCG/branch/reset/DFS table and .flags =
CLK_SET_RATE_PARENT (a real mainline init flag). Also modernizes the include
block and the compatible string to mainline convention.
"""
import re, sys

src = open("gcc-cliffs.c").read().splitlines(keepends=True)
out = []
i = 0
n = len(src)

MAINLINE_INCLUDES = """#include <linux/clk-provider.h>
#include <linux/mod_devicetable.h>
#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/regmap.h>

#include <dt-bindings/clock/qcom,gcc-cliffs.h>

#include "clk-alpha-pll.h"
#include "clk-branch.h"
#include "clk-rcg.h"
#include "clk-regmap-divider.h"
#include "clk-regmap-mux.h"
#include "common.h"
#include "reset.h"
"""

vdd_re   = re.compile(r'^\s*(\.clkr)?\.vdd_data\s*=\s*\{')
drop_line = re.compile(
    r'^\s*('
    r'\.enable_safe_config\s*=|'
    r'\.flags\s*=\s*HW_CLK_CTRL_MODE\s*,|'
    r'\.flags\s*=\s*CLK_DONT_HOLD_STATE\s*,|'
    r'\.clk_regulators\s*=|'
    r'\.num_clk_regulators\s*=|'
    r'static\s+DEFINE_VDD_REGULATORS\('
    r')'
)

# splice the include block (lines 6..22 in the original, 1-based) in one go
include_start = None
include_done = False

while i < n:
    line = src[i]

    # replace the whole include region the first time we hit the first #include
    if not include_done and line.startswith('#include'):
        out.append(MAINLINE_INCLUDES)
        # skip original includes up to and including vdd-level.h
        while i < n and (src[i].startswith('#include') or src[i].strip() == ''):
            # stop after we've consumed the vdd-level.h line
            consumed_vdd = 'vdd-level.h' in src[i]
            i += 1
            if consumed_vdd:
                break
        include_done = True
        continue

    # drop the regulators array: static struct clk_vdd_class *..._regulators[] = { ... };
    if re.match(r'^\s*static struct clk_vdd_class \*gcc_cliffs_regulators\[\]', line):
        while i < n and src[i].rstrip().endswith('};') is False:
            i += 1
        i += 1  # skip the '};'
        # also swallow a following blank line
        if i < n and src[i].strip() == '':
            i += 1
        continue

    # brace-match remove vdd_data blocks
    if vdd_re.match(line):
        depth = 0
        started = False
        while i < n:
            depth += src[i].count('{') - src[i].count('}')
            i += 1
            started = True
            if started and depth == 0:
                break
        continue

    # single-line drops
    if drop_line.match(line):
        i += 1
        continue

    # compatible rename
    if '"qcom,cliffs-gcc"' in line:
        line = line.replace('"qcom,cliffs-gcc"', '"qcom,gcc-sm8635"')

    out.append(line)
    i += 1

text = ''.join(out)

# --- mainline API adaptations (compile-verified against linux 7.1) ---
# 1. qcom_cc_really_probe() takes struct device *, not platform_device *.
text = text.replace("qcom_cc_really_probe(pdev,", "qcom_cc_really_probe(&pdev->dev,")
# 2. qcom_cc_sync_state / .sync_state do not exist upstream; drop them.
text = re.sub(r'\nstatic void gcc_cliffs_sync_state\(struct device \*dev\)\n\{\n'
              r'\tqcom_cc_sync_state\(dev, &gcc_cliffs_desc\);\n\}\n', '\n', text)
text = re.sub(r'\n\t\t\.sync_state = gcc_cliffs_sync_state,', '', text)
# 3. clk_branch2_hw_ctl_ops is downstream-only; mainline uses clk_branch2_ops
#    for the *_hw_ctl_clk branches (as gcc-sm8650 does).
text = text.replace("&clk_branch2_hw_ctl_ops", "&clk_branch2_ops")

# collapse 3+ blank lines to 1
text = re.sub(r'\n\n\n+', '\n\n', text)
open("gcc-sm8635.c", "w").write(text)
print("wrote gcc-sm8635.c  lines:", text.count("\n"))
