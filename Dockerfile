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
    GOOS="${goos}" GOARCH="${goarch}" go install -trimpath -ldflags="-s -w" github.com/minio/minio/cmd/minio@"${MINIO_VERSION}"; \
    test -x "/go/bin/minio"

FROM alpine:3.22.2

ARG MINIO_VERSION

ENV MINIO_USER=minio \
    MINIO_GROUP=minio \
    MINIO_VOLUMEDIR=/data

RUN set -eux; \
    apk add --no-cache ca-certificates tzdata; \
    addgroup -S "${MINIO_GROUP}"; \
    adduser -S -G "${MINIO_GROUP}" "${MINIO_USER}"; \
    mkdir -p "${MINIO_VOLUMEDIR}"; \
    chown -R "${MINIO_USER}:${MINIO_GROUP}" "${MINIO_VOLUMEDIR}"

COPY --from=builder /go/bin/minio /usr/local/bin/minio

USER ${MINIO_USER}:${MINIO_GROUP}

VOLUME ["/data"]
EXPOSE 9000 9001

HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 CMD /usr/local/bin/minio --version > /dev/null || exit 1

ENTRYPOINT ["/usr/local/bin/minio"]
CMD ["server","/data","--console-address",":9001"]
