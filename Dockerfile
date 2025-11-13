# syntax=docker/dockerfile:1.6

FROM --platform=$BUILDPLATFORM golang:1.25.4-alpine AS builder

ARG TARGETOS=linux
ARG TARGETARCH
ARG MINIO_VERSION

ENV CGO_ENABLED=0 \
  GO111MODULE=on

RUN apk add --no-cache ca-certificates git

RUN set -eux; \
  : "${MINIO_VERSION:?Build argument MINIO_VERSION is required}"; \
  goos="${TARGETOS:-$(go env GOOS)}"; \
  goarch="${TARGETARCH:-$(go env GOARCH)}"; \
  case "${goarch}" in \
    amd64|arm64) ;; \
    *) echo "Unsupported TARGETARCH: ${goarch}" >&2; exit 1 ;; \
  esac; \
  git clone --depth 1 --branch "${MINIO_VERSION}" https://github.com/minio/minio.git /src; \
  cd /src; \
  export GOOS="${goos}" GOARCH="${goarch}"; \
  ldflags="$(go run buildscripts/gen-ldflags.go)"; \
  go build -tags kqueue -trimpath --ldflags "${ldflags}" -o /out/minio

FROM alpine:3.22.2

ARG MINIO_VERSION

LABEL org.opencontainers.image.title="MinIO" \
    org.opencontainers.image.description="Community build of MinIO server per upstream release tag." \
    org.opencontainers.image.source="https://github.com/morzan1001/minio-docker" \
    org.opencontainers.image.version="${MINIO_VERSION}" \
    org.opencontainers.image.vendor="Community"

RUN set -eux; \
  apk add --no-cache ca-certificates tzdata util-linux;

COPY --from=builder /out/minio /usr/bin/minio
COPY dockerscripts/docker-entrypoint.sh /usr/bin/docker-entrypoint.sh

RUN chmod +x /usr/bin/minio /usr/bin/docker-entrypoint.sh

EXPOSE 9000
VOLUME ["/data"]

HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 CMD minio --version >/dev/null || exit 1

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["minio"]







