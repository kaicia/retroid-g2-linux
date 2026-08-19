# Retroid Pocket G2 Device Tree Investigation

## SDHCI

Node:

/sys/firmware/devicetree/base/soc/sdhci@8804000

Compatible:

qcom,sdhci-msm-v5

Reg:

08 80 40 00 00 00 10 00

Bus width:

00 00 00 04

Status:

ok

## Pinctrl

Controller:

/sys/firmware/devicetree/base/soc/pinctrl@f000000

Compatible:

qcom,cliffs-pinctrl

### sdc2_on

- CLK: gpio62
- CMD: gpio51
- DATA: gpio38 gpio39 gpio48 gpio49
- SD-CD: gpio31

### sdc2_off

- CLK: gpio62
- CMD: gpio51
- DATA: gpio38 gpio39 gpio48 gpio49
- SD-CD: gpio31

### Pinctrl references

- pinctrl-0 = 0x3ac
- pinctrl-1 = 0x3ad
- pinctrl-names = default, sleep

## CD GPIO

cd-gpios:

00 00 01 6c 00 00 00 1f 00 00 00 01

GPIO controller:

pinctrl@f000000

GPIO:

31

cd-debounce-delay-ms:

1500 ms

## Regulators

vdd-supply:

phandle 0x352

rpmh-regulator-ldob13/regulator-pmxr2230-l13

vdd-io-supply:

phandle 0x359

rpmh-regulator-ldob23/regulator-pmxr2230-l23

## Raw evidence

See:

../dumps/g2/g2_sdhci_dt_dump.txt
