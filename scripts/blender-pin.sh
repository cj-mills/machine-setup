#!/usr/bin/env bash
# Print the pins for an official Blender release, each SHA-256 verified identical
# across independent mirrors:
#   - Linux:   the `blender_versions` entry (ansible/inventory/group_vars/workstation.yml)
#   - Windows: the MSI version and checksum (windows/machine-setup/configuration.winget,
#              unit `blender`)
# Only published releases are on the mirrors, so betas and release candidates can't
# be pinned by mistake.
#
# Usage: scripts/blender-pin.sh 5.3      latest patch release of a series
#        scripts/blender-pin.sh 5.3.1    an exact release

set -euo pipefail

mirrors=(
  https://mirrors.ocf.berkeley.edu/blender/release
  https://ftp.nluug.nl/pub/graphics/blender/release
  https://mirror.clarkson.edu/blender/release
)

die() { echo "error: $*" >&2; exit 1; }

# sum_of SERIES VERSION FILE: the file's SHA-256, identical on every mirror (or die).
sum_of() {
  local series="$1" version="$2" file="$3" sums=() sum mirror
  for mirror in "${mirrors[@]}"; do
    sum="$(curl -fsSL --max-time 30 "$mirror/Blender$series/blender-$version.sha256" \
      | awk -v f="$file" '$2 == f || $2 == "*" f {print $1}')" || true
    [[ -n "$sum" ]] || die "no checksum for $file on $mirror"
    sums+=("$sum")
  done
  [[ "$(printf '%s\n' "${sums[@]}" | sort -u | wc -l)" -eq 1 ]] \
    || die "mirrors disagree on the checksum for $file: ${sums[*]}"
  echo "${sums[0]}"
}

# Everything below runs inside main(), which bash parses completely before running.
main() {
  local arg="${1:-}" series version
  if [[ "$arg" =~ ^[0-9]+\.[0-9]+$ ]]; then
    series="$arg"
    version="$(curl -fsSL --max-time 30 "${mirrors[0]}/Blender$series/" \
      | grep -oE "blender-${series//./\\.}\.[0-9]+-linux-x64\.tar\.xz" \
      | sed -E 's/^blender-(.*)-linux-x64\.tar\.xz$/\1/' | sort -uV | tail -1)" || true
    [[ -n "$version" ]] || die "no released Linux build found for series $series"
  elif [[ "$arg" =~ ^([0-9]+\.[0-9]+)\.[0-9]+$ ]]; then
    series="${BASH_REMATCH[1]}"
    version="$arg"
  else
    die "usage: $0 <series, e.g. 5.3 | version, e.g. 5.3.1>"
  fi

  local linux_sum windows_sum
  linux_sum="$(sum_of "$series" "$version" "blender-$version-linux-x64.tar.xz")"
  windows_sum="$(sum_of "$series" "$version" "blender-$version-windows-x64.msi")"

  echo "# Linux: ansible/inventory/group_vars/workstation.yml, blender_versions"
  echo "  - version: $version"
  echo "    sha256: $linux_sum"
  echo "# Windows: windows/machine-setup/configuration.winget, unit blender"
  echo "  version: $version"
  echo "  sha256:  $windows_sum"
}

main "$@"; exit
