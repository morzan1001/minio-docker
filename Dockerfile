# syntax=docker/dockerfile:1.6

FROM --platform=$BUILDPLATFORM golang:1.25.4-alpine AS builder

ARG TARGETOS=linux
ARG TARGETARCH
ARG MINIO_VERSION

ENV CGO_ENABLED=0

RUN apk add --no-cache git

RUN set -eux; \
    : "${MINIO_VERSION:?Build argument MINIO_VERSION is required}"; \
    goos="${TARGETOS:-linux}"; \
    goarch="${TARGETARCH:-}"; \
    if [ -z "${goarch}" ]; then \
      goarch="$(go env GOARCH)"; \
    fi; \
    case "${goarch}" in \
      amd64|arm64) ;; \
      *) echo "Unsupported TARGETARCH: ${goarch}" >&2; exit 1 ;; \
    esac; \
    mkdir -p /out; \
    git clone --depth 1 --branch "${MINIO_VERSION}" https://github.com/minio/minio.git /src; \
    cd /src; \
    echo "Building from repository root"; \
    GOOS="${goos}" GOARCH="${goarch}" go build -trimpath -ldflags="-s -w" -o /out/minio .

FROM alpine:3.22.2

ARG MINIO_VERSION

LABEL org.opencontainers.image.title="MinIO" \
      org.opencontainers.image.description="Minimal community build of MinIO server per upstream release tag." \
      org.opencontainers.image.source="https://github.com/minio/minio" \
      org.opencontainers.image.version="${MINIO_VERSION}" \
      org.opencontainers.image.vendor="Community" \
      org.opencontainers.image.licenses="AGPL-3.0-only"

ENV MINIO_USER=minio \
    MINIO_GROUP=minio \
    MINIO_VOLUMEDIR=/data

RUN set -eux; \
    apk add --no-cache ca-certificates tzdata curl; \
    addgroup -S "${MINIO_GROUP}"; \
    adduser -S -G "${MINIO_GROUP}" "${MINIO_USER}"; \
    mkdir -p "${MINIO_VOLUMEDIR}"

COPY --from=builder /out/minio /usr/local/bin/minio

RUN set -eux; \
    chmod +x /usr/local/bin/minio; \
    chown "${MINIO_USER}:${MINIO_GROUP}" /usr/local/bin/minio

USER ${MINIO_USER}:${MINIO_GROUP}

VOLUME ["/data"]
EXPOSE 9000 9001

HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 CMD /usr/local/bin/minio --version > /dev/null || exit 1

ENTRYPOINT ["/usr/local/bin/minio"]
CMD ["server","/data","--console-address",":9001"]
