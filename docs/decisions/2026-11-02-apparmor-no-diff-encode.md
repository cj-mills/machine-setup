---
status: accepted
decided_by: agent, in answer to the user's request to fix Firefox's AppArmor confinement
source: session 2026-11-02-firefox-deb-fix
---
# AppArmor policy compiled without diff encoding

**Decision.** The `base` role adds `Optimize=no-diff-encode` to
`/etc/apparmor/parser.conf` and reloads AppArmor, until a kernel with a fix for
[apparmor-kernel#8](https://gitlab.com/apparmor/apparmor-kernel/-/issues/8) ships.

**Why.** With kernel 7.0 and parser 5.0.2 (Ubuntu 26.04), an attachment that nests
alternations, such as Ubuntu's `firefox` profile
(`/{usr/lib/firefox{,-esr,…},opt/firefox}/firefox{,-esr,-bin}`), never matches through
its nested branch, and no audit message says so. The kernel's attachment matcher
mishandles diff-encoded DFA states; file rules use another path and are unaffected.
Mozilla's deb then runs unconfined, AppArmor's user-namespace restriction denies it
`sys_admin` in its namespaces, and Firefox's sandbox loses that layer. Tested in the
ms-test VM on 2026-11-02: nested attachments fail and flat ones attach; with this option
Firefox runs as `firefox (unconfined)`, content processes get their own user namespace,
and nothing is denied. Without diff encoding, compiled policy is larger, nothing else
changes, and it fixes every profile with such an attachment, not just Firefox's.

**Rejected.**
- An extra profile with a flat attachment for `/usr/lib/firefox/firefox{,-bin}`. Once
  the kernel is fixed, Ubuntu's profile would match the same path with the same
  specificity, and the kernel attaches neither of two conflicting profiles (inferred from
  the kernel's attachment rules; seen in the VM with a test profile beside the fixed
  `firefox` one). It also fixes only Firefox.
- Editing `/etc/apparmor.d/firefox`, a conffile of the `apparmor` package that its
  updates replace or prompt about. `parser.conf` is a conffile too, but a single added
  option line that the role re-adds if an update drops it.
- Turning off `kernel.apparmor_restrict_unprivileged_userns`, which lifts the
  restriction for every program.
