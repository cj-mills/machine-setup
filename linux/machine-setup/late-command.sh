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

# The private inventory overlay (the machine's own facts, e.g. its drives' UUIDs), which
# scripts/build-install-media.sh adds to the media: the first boot converges with it,
# before the drive holding its source is mounted. Root only.
install -d -m 755 "$target/etc/machine-setup"
rm -rf "$target/etc/machine-setup/inventory"
cp -r "$here/inventory" "$target/etc/machine-setup/inventory"
chown -R root:root "$target/etc/machine-setup/inventory"
chmod -R go= "$target/etc/machine-setup/inventory"

# Present on test VM media only; see scripts/test-vm.sh.
for hook in "$here"/test-hooks/*.sh; do
  if [ -f "$hook" ]; then sh "$hook"; fi
done
