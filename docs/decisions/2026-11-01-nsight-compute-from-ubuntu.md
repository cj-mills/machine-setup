---
status: accepted
source: docs/design.md decisions table, converted verbatim 2026-11-02
---
# Nsight Compute comes from Ubuntu's archive

Nsight Compute comes from Ubuntu's archive (`nsight-compute`, 2024.1 on 26.04), with its profiling option in the `nvidia` role, replacing a hand install in `/usr/local` and the older 2022.4 package beside it. Rejected: NVIDIA's CUDA apt repo (2026.3), a second source of NVIDIA packages next to a driver from Ubuntu's archive, for a tool used occasionally.
