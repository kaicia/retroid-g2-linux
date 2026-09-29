# kernel/sm8635/bootloader/

Boot-partition payload for the SD image, per the chosen BOOTLOADER mode in the
device profile (`devices/sm8635/profile.conf` in a holodor checkout):

- **arm-efi (Path A):** GRUB `bootaa64.efi` + `grub.cfg` (+ dtbs copied in at
  build time). Populated only if Path A re-verification passes — see
  `docs/g2-path-a-reverify-20260929.md`. Build the GRUB image with
  `grub-mkimage -O arm64-efi -p /boot/grub ...`.
- **qcom-abl (Path B):** `rocknix_abl/` (signed ELF + flash scripts). Blocked on a
  Cliffs ABL (`ROCKNIX/LinuxLoader` is private) — see
  `docs/g2-boot-strategy-rocknix-abl-20260928.md`.

Empty until the boot path is settled by the Path A test.
