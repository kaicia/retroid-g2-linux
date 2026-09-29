#!/usr/bin/env python3
"""Port drivers/pinctrl/qcom/pinctrl-cliffs.c (Xiaomi peridot-u-oss, msm-6.1)
to the mainline qcom TLMM pinctrl framework. Removes downstream-only pieces:
  - I3C-QUP machinery: QUP_I3C() macro, QUP_*_MODE_OFFSET defines,
    cliffs_qup_regs[] (struct pinctrl_qup), .qup_regs/.nqup_regs soc_data fields
    (mainline msm_pinctrl_soc_data has none of these)
  - the -vm- (virtual-machine guest) pinctrl variant + its of_match entry +
    MODULE_SOFTDEP on the downstream qcom_tlmm_vm_irqchip
  - MIUI .pm hook: noirq_msm_pinctrl_dev_pm_ops -> mainline msm_pinctrl_dev_pm_ops
Keeps all pins, functions, groups, PINGROUP/UFS_RESET macros, the pdc wakeirq
map, and egpio support. Renames compatible qcom,cliffs-pinctrl ->
qcom,sm8635-tlmm (mainline convention).
"""
import re

lines = open("pinctrl-cliffs.c").read().splitlines(keepends=True)
out = []
i, n = 0, len(lines)

def is_block_start(s, pat):
    return re.match(pat, s) is not None

while i < n:
    line = lines[i]

    # 1) QUP_I3C() macro: #define with backslash-continued body
    if line.startswith('#define QUP_I3C('):
        while i < n:
            cont = lines[i].rstrip('\n').endswith('\\')
            i += 1
            if not cont:
                break
        # swallow one trailing blank line
        if i < n and lines[i].strip() == '':
            i += 1
        continue

    # 2) QUP_*_MODE_OFFSET defines
    if re.match(r'#define QUP_\d.*_MODE_OFFSET\b', line):
        i += 1
        # swallow trailing blank once the last offset define is gone
        if i < n and lines[i].strip() == '' and not lines[i-1].startswith('#define QUP_'):
            pass
        continue

    # 3) cliffs_qup_regs[] array
    if is_block_start(line, r'static struct pinctrl_qup cliffs_qup_regs\[\]'):
        while i < n and lines[i].rstrip('\n') != '};':
            i += 1
        i += 1  # skip '};'
        if i < n and lines[i].strip() == '':
            i += 1
        continue

    # 4) cliffs_vm_pinctrl soc_data block
    if is_block_start(line, r'static const struct msm_pinctrl_soc_data cliffs_vm_pinctrl'):
        while i < n and lines[i].rstrip('\n') != '};':
            i += 1
        i += 1
        if i < n and lines[i].strip() == '':
            i += 1
        continue

    # 5) single-line drops
    if re.match(r'\s*\.(n?qup_regs)\s*=', line):
        i += 1; continue
    if 'qcom,cliffs-vm-pinctrl' in line:
        i += 1; continue
    if line.strip() in ('// MIUI ADD: Power_LogEnhance', '// END Power_LogEnhance'):
        i += 1; continue
    if 'MODULE_SOFTDEP("pre: qcom_tlmm_vm_irqchip")' in line:
        i += 1; continue

    # 6) substitutions
    line = line.replace('noirq_msm_pinctrl_dev_pm_ops', 'msm_pinctrl_dev_pm_ops')
    line = line.replace('"qcom,cliffs-pinctrl"', '"qcom,sm8635-tlmm"')

    out.append(line)
    i += 1

text = ''.join(out)
text = re.sub(r'\n\n\n+', '\n\n', text)
open("pinctrl-sm8635.c", "w").write(text)
print("wrote pinctrl-sm8635.c  lines:", text.count("\n"))
