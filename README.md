# RHEL 9 micro Hardened Base (ubi9-micro)

A **distroless**, security-hardened Red Hat Enterprise Linux 9 base image built on
**UBI 9-micro** — no package manager, no shell, non-root — for the smallest
possible attack surface and a **0-CVE target**.

Sibling of [`rhel9-hardened-base`](https://github.com/kelleyblackmore/rhel9-hardened-base)
(the full, DISA-STIG-verified UBI 9 base). Use **this** image when you want minimal
CVEs and don't need `dnf`/a shell at runtime; use the full base when you need STIG
compliance or to `dnf install` inside the image.

## Why it's tiny (and near-zero CVE)

UBI 9-micro ships **no `dnf`, no `rpm`, no shell**. The image is built with the
Red Hat multi-stage pattern:

1. a **builder** stage (full UBI 9, which has `dnf`) installs a minimal package
   set into a clean rootfs via `--installroot`, updated to the latest available;
2. the **final** stage is `FROM ubi9-micro` and just `COPY`s that rootfs in.

The result contains only `ca-certificates`, `tzdata`, and their minimal library
closure (glibc, openssl-libs, p11-kit, crypto-policies …) — nothing else to carry
CVEs. There is no editor, debugger, package manager, or shell to exploit.

## CVE policy (verified in CI)

[`cve-scan.yml`](.github/workflows/cve-scan.yml) builds the image and runs Trivy
across **all severities including unfixed**, then:

- **Hard-fails** on any **fixable** CVE (means the image isn't on the latest — rebuild).
- Reports the **true total**; residual CVEs are all **unfixed** (no upstream patch —
  "impossible to update to the latest"), surfaced daily so they're caught the
  moment a fix ships.

The live counts are in the workflow's job summary and the `trivy-micro` artifact.

### The honest ceiling on UBI 9-micro

This image reaches **0 fixable CVEs** with only a small set of **unfixed** ones
(dominated by `glibc` and the OpenSSL/CA-trust stack). **Literal 0 total is not
achievable on any UBI 9 image** while Red Hat has open, unpatched CVEs in `glibc`
(which every dynamically-linked container needs) — Trivy reports those as
`affected / no fix`. The remainder here is essentially:

- `glibc` / `libgcc` — irreducible (the C runtime).
- `openssl-libs` / `p11-kit` — pulled by `ca-certificates` (TLS trust). Drop
  `ca-certificates` for an even smaller, TLS-less variant if your workload adds
  its own trust store.
- `libacl` / `libattr` — pulled by the coreutils dependency closure.

For a **literal 0-CVE** image you need a distro that rebuilds packages with fixes
ahead of Red Hat's cadence (e.g. Chainguard/Wolfi or Minimus) — a different
ecosystem, outside RHEL/UBI.

## Using it

Because there is no shell, downstream images provide an **exec-form**
`ENTRYPOINT`/`CMD` and copy in a static or glibc-linked binary:

```dockerfile
FROM ghcr.io/kelleyblackmore/rhel9-micro-hardened-base:latest
COPY --chown=10001:0 myapp /app/myapp
USER 10001
ENTRYPOINT ["/app/myapp"]
```

Notes:
- Runs as non-root **UID 10001** (group 0, OpenShift-friendly) by default.
- No shell means no `RUN`, `sh -c`, or shell-form `CMD` in downstream images.
- For Go/Rust/static binaries, consider `FROM scratch`; use this image when you
  need glibc + CA trust + tzdata without a full OS.

## Automation

- **Renovate** ([`renovate.json`](renovate.json)) opens weekly PRs to bump the
  pinned `ubi9-micro` / `ubi9` builder digests and GitHub Actions (requires the
  Mend Renovate GitHub App installed).
- **Weekly rebuild** ([`build-and-push.yml`](.github/workflows/build-and-push.yml))
  republishes `latest` with the newest patched packages.
- **Daily CVE scan** ([`cve-scan.yml`](.github/workflows/cve-scan.yml)) enforces
  the 0-CVE / 0-fixable policy.
