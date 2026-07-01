# syntax=docker/dockerfile:1
# =============================================================================
# RHEL 9 / UBI 9-micro hardened base — distroless, minimal, 0-CVE target.
#
# ubi-micro has NO package manager and NO shell. The standard build pattern is:
#   1. a "builder" stage (full UBI9, has dnf) installs a minimal package set into
#      a clean rootfs via --installroot, updated to the latest available;
#   2. the final stage is FROM ubi-micro and just COPYs that rootfs in.
# The result is a tiny, non-root, shell-less image whose only attack surface is
# the handful of libraries a base truly needs.
# =============================================================================
ARG UBI_MICRO=registry.access.redhat.com/ubi9/ubi-micro:latest
ARG UBI_BUILDER=registry.access.redhat.com/ubi9/ubi:latest

# ---- builder: install a minimal, fully-updated package set into /mnt/rootfs ----
FROM ${UBI_BUILDER} AS builder
ARG ROOTFS=/mnt/rootfs
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]
RUN mkdir -p "${ROOTFS}"; \
    # Install ONLY what a base image needs; no weak deps, no docs.
    dnf -y --installroot="${ROOTFS}" --releasever=9 \
        --setopt=install_weak_deps=0 --setopt=tsflags=nodocs \
        install ca-certificates tzdata; \
    # Ensure everything is at the latest available (security) version.
    dnf -y --installroot="${ROOTFS}" --releasever=9 update; \
    dnf -y --installroot="${ROOTFS}" clean all; \
    rm -rf "${ROOTFS}"/var/cache/* "${ROOTFS}"/var/log/* \
           "${ROOTFS}"/tmp/* "${ROOTFS}"/var/tmp/* 2>/dev/null || true; \
    # Non-root, OpenShift-friendly (group 0) user baked into the rootfs.
    echo 'appuser:x:10001:0:app user:/app:/sbin/nologin' >> "${ROOTFS}/etc/passwd"; \
    mkdir -p "${ROOTFS}/app"; \
    chown -R 10001:0 "${ROOTFS}/app"; \
    chmod -R g=u "${ROOTFS}/app"

# ---- final: distroless micro + our rootfs ----
FROM ${UBI_MICRO}
LABEL \
  name="ubi9-micro-hardened-base" \
  vendor="kelleyblackmore" \
  summary="Distroless UBI9-micro hardened base (0-CVE target)" \
  description="Minimal, shell-less, package-manager-less, non-root UBI9-micro base for statically- or glibc-linked application images" \
  org.opencontainers.image.title="ubi9-micro-hardened-base" \
  org.opencontainers.image.source="https://github.com/kelleyblackmore/rhel9-micro-hardened-base" \
  org.opencontainers.image.licenses="MIT"

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC

COPY --from=builder /mnt/rootfs/ /

USER 10001
WORKDIR /app

# There is no shell in a micro image. Downstream images provide an exec-form
# ENTRYPOINT/CMD, e.g.:  COPY myapp /app/  ;  ENTRYPOINT ["/app/myapp"]
