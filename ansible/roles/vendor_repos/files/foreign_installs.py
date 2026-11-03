#!/usr/bin/python3
"""Print `name=version` for vendor packages installed from another archive.

Arguments are `name=host` pairs: a package and the host of its vendor repository.
A package is reported when its installed version is published by some other archive
but not by the vendor (e.g. Ubuntu's `firefox`, a transitional wrapper for the snap,
which `state: present` counts as installed). The version printed is the vendor's
newest, which the caller installs over it, as a downgrade if need be. A version
published by no archive at all (one the vendor has since dropped) is left alone.
"""

import sys

import apt


def main(pairs):
    cache = apt.Cache()
    for pair in pairs:
        name, host = pair.split("=", 1)
        pkg = cache.get(name)
        if pkg is None or pkg.installed is None:
            continue
        sites = {o.site for o in pkg.installed.origins if o.site}
        if not sites or host in sites:
            continue
        vendor = [v for v in pkg.versions if any(o.site == host for o in v.origins)]
        if vendor:
            print(f"{name}={max(vendor).version}")


main(sys.argv[1:])
