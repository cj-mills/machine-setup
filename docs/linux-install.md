# Ubuntu install runbook (workstation)

Fresh Ubuntu 26.04 on the Linux drive (Samsung 990 PRO 4TB). This erases that drive and
nothing else: the install media name it by its serial, which is with the machine's other
facts in the private directory (`docs/design.md`, "Drive layout"). Everything here was
rehearsed on the replica VM (`VM_NAME=ms-replica VM_OS=replica scripts/test-vm.sh`),
which has the same drive sizes, serials and filesystem UUIDs. Background and decisions: `docs/design.md`.

Before starting, back up whatever in `~` isn't reproducible and take a final
`backup-snapshot` (`docs/design.md`, "Workstation install flow"), and push `main`: first
boot clones this repository from GitHub. Leave the Ethernet cable plugged in.

## 1. Build the media

The stick's filesystem is read-only, so the config can't be copied onto it: the stick is
rewritten from a repacked image.

```bash
scripts/build-install-media.sh build /mnt/data/vm/isos/ubuntu-26.04.1-desktop-amd64.iso /mnt/data/vm/isos/innom-dt-install.iso
```

It asks for the login password of the new install. Only a salted hash goes into the image,
which stays out of the repository, and you can change the password after installing. The
drive's serial and the private inventory overlay come from `MACHINE_SETUP_PRIVATE`
(default: the hub).

Then write it. This erases the stick, after showing what's on it and asking you to type its
name back:

```bash
sudo scripts/build-install-media.sh write /mnt/data/vm/isos/innom-dt-install.iso /dev/disk/by-id/usb-<the stick>
```

## 2. Install

Boot the stick from the firmware boot menu and take the default menu entry. The stock
**Try or Install Ubuntu** entry is the right one; there's no separate install option.

The installer stops at **Ready to install**, showing the config, with the drive it will
erase at the top. On a machine without that drive's serial it stops with an error before
this page, so nothing can be erased by accident. A BitLocker notice is expected here: it's
about the Windows drive, which isn't touched.

Press **Install** and walk away. The install finishes and reboots by itself; the stick can
stay in, because the new install's boot entry goes first.

## 3. First boot

Before the login screen, `machine-setup-first-boot.service` runs `bootstrap.sh` on `tty1`
(system layer, data-drive mounts, NVIDIA driver), then reboots once into the finished
system. Its log is `/var/log/machine-setup-first-boot.log`.

If it fails, it stops on screen and waits: press Enter to retry, or type `skip` for the
login screen. It also runs again at every boot until it succeeds. Other consoles are on
Ctrl+Alt+F3, for looking around.

## 4. User layer

Sign in, then from a desktop terminal (GNOME settings need a session bus):

1. Open 1Password and sign in. Under Settings → Developer, enable "Integrate with
   1Password CLI" and "Use the SSH agent".
2. Run `~/.local/bin/chezmoi apply`.

## 5. Tidy up

- `sudo efibootmgr` still lists the old install's entries, on an ESP that no longer exists.
  Firmware skips them; delete each with `sudo efibootmgr -b XXXX -B`. Keep the new `Ubuntu`
  entry and the `Windows Boot Manager` on the Windows drive.
- Start Windows from the firmware boot menu, not GRUB (`docs/windows-install.md`).
