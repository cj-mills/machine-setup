# Windows install runbook (workstation)

Fresh Windows 11 Pro on its own drive (Samsung 990 PRO 4TB, serial …701402T), next to
the Linux drive (990 PRO 4TB, serial …123428Y). Everything here was rehearsed in the
test VM (`VM_NAME=ms-win scripts/test-vm.sh`), whose "decoy" disk stands in for the
Linux drive. Background and decisions: `docs/design.md`.

**Both 990 PROs are 4 TB.** On Windows Setup's disk page, the Windows drive is the one
showing a single **Unallocated Space** entry and no partitions; the Linux drive shows
several partitions.

## 1. Prepare, from Linux

```bash
# The drive's old NTFS partition is still mounted; unmount it first, and drop its
# /etc/fstab entry (mounted by that partition's UUID, which the erase removes).
sudo umount /mnt/990_PRO_4TB
sudo sed -i '\|/mnt/990_PRO_4TB|d' /etc/fstab
sudo rmdir /mnt/990_PRO_4TB

# Erase the Windows drive to an empty GPT (asks you to type its name back).
sudo scripts/prepare-windows-disk.sh /dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNU0X701402T

# Hide the Linux drive's EFI system partition from Windows Setup (partition-table
# metadata only), so Setup creates its own ESP on the Windows drive.
sudo scripts/esp-visibility.sh hide /dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNJ0X123428Y

# Confirm no other ESP is visible anywhere (expect no output).
lsblk -o NAME,PARTTYPE,SIZE | grep -i c12a7328
```

Copy the answer file and `machine-setup\` folder to the root of the installer USB
(`ESD-USB`):

```bash
cp windows/autounattend.xml /media/$USER/ESD-USB/
cp -r windows/machine-setup /media/$USER/ESD-USB/
```

## 2. Install

1. Reboot and open the firmware's **one-time boot menu** (MSI: F11). Pick the USB stick's
   UEFI entry. (Don't put the USB first in the permanent boot order: after Setup's
   first reboot it would boot the installer again.)
2. On **"Where do you want to install Windows?"**, select the **Unallocated Space** entry
   on the drive that has no partitions (~3726 GB). Everything after this is unattended.
3. At the lock screen after the first sign-in, Windows asks you to set the account's
   password (the answer file stores none).

What happens unattended: Windows 11 Pro, local admin account `innom-dt`, computer name
`INNOM-DT-WIN`, no automatic device encryption, and at first sign-in
`C:\machine-setup\first-logon.ps1` confirms the boot files are on the Windows drive's own
ESP (log: `C:\machine-setup\first-logon.log`).

## 3. Configure

From **Terminal (Admin)**, with a network connection:

```powershell
C:\machine-setup\bootstrap.ps1
```

Accept the configuration agreement when prompted. It may first update winget from the
Store, then runs a read-only test pass, then applies everything (apps, settings,
removals). Re-runnable; then **restart Windows**.

## 4. Manual steps

- **BitLocker**: Settings → Privacy & security → Device encryption (or Control Panel →
  BitLocker). Save the recovery key in 1Password **before** finishing. Start Windows
  from the firmware boot menu, not GRUB, to avoid recovery-key prompts.
- **Vendor installers** (not in winget): Samsung Magician, NVIDIA App (switch to the
  Studio driver branch; overlay off unless recording), ArtCraft.
- **Start menu**: pin your working set; Windows offers no unlocked way to declare pins.
- **Audio files**: the first time you open one, choose VLC and "Always" (Media Player is
  removed; default apps can't be set from a script).

## 5. Restore the Linux ESP

The old Ubuntu install boots from the Linux drive's ESP, hidden in step 1. Restore it
before relying on that install (the Ubuntu clean install creates a new ESP anyway):

```bash
sudo scripts/esp-visibility.sh show /dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNJ0X123428Y
```

If the old Ubuntu won't boot while the ESP is hidden, restore it from Windows instead
(elevated `diskpart`; the Linux drive's disk number is in `list disk`, its ESP is
partition 2):

```
select disk <N>
select partition 2
set id=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
```
