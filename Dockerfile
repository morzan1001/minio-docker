# syntax=docker/dockerfile:1.6

FROM alpine:latest

ARG MINIO_VERSION
ARG TARGETOS
ARG TARGETARCH

ENV MINIO_USER=minio
ENV MINIO_GROUP=minio
ENV MINIO_VOLUMEDIR=/data

RUN set -eux; \
    : "${MINIO_VERSION:?Build argument MINIO_VERSION is required}"; \
    addgroup -S "${MINIO_GROUP}" && adduser -S -G "${MINIO_GROUP}" "${MINIO_USER}"; \
    apk add --no-cache ca-certificates curl tzdata; \
    case "${TARGETARCH}" in \
      amd64) ARCH="amd64" ;; \
      arm64) ARCH="arm64" ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    BIN_URL="https://dl.min.io/server/minio/release/${TARGETOS}-${ARCH}/archive/minio.${MINIO_VERSION}"; \
    curl -fsSL "${BIN_URL}" -o /usr/local/bin/minio; \
    chmod +x /usr/local/bin/minio; \
    mkdir -p "${MINIO_VOLUMEDIR}"; \
    chown -R "${MINIO_USER}:${MINIO_GROUP}" "${MINIO_VOLUMEDIR}"

VOLUME ["/data"]
EXPOSE 9000 9001

USER ${MINIO_USER}:${MINIO_GROUP}

HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 CMD /usr/local/bin/minio --version > /dev/null || exit 1

ENTRYPOINT ["/usr/local/bin/minio"]
CMD ["server","/data","--console-address",":9001"]
