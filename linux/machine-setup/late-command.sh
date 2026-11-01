#!/bin/sh
# Autoinstall late command: arrange for first-boot.sh to run in the installed system.
# Runs in the installer, with the new system at /target. The service is enabled by
# link because systemctl can't be relied on from inside the installer's snap.
set -eu

here="$(dirname "$0")"
target=/target

install -d "$target/usr/local/lib/machine-setup"
install -m 755 "$here/first-boot.sh" "$here/bootstrap.sh" "$target/usr/local/lib/machine-setup/"
install -m 644 "$here/machine-setup-first-boot.service" "$target/etc/systemd/system/"
ln -sf ../machine-setup-first-boot.service \
  "$target/etc/systemd/system/multi-user.target.wants/machine-setup-first-boot.service"

# Present on test VM media only; see scripts/test-vm.sh.
for hook in "$here"/test-hooks/*.sh; do
  if [ -f "$hook" ]; then sh "$hook"; fi
done
