# =============================================================================
# TelemetryFlow Platform - Operator Dockerfile
# Multi-stage build for Kubernetes Operator
# =============================================================================

# =============================================================================
# Build stage
# =============================================================================
FROM golang:1.26-alpine AS builder

WORKDIR /workspace

RUN apk add --no-cache git ca-certificates tzdata

COPY go.mod go.sum ./
RUN go mod download

COPY main.go main.go
COPY api/ api/
COPY internal/ internal/

ARG TARGETOS
ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -ldflags="-s -w" -o /manager main.go

# =============================================================================
# Production stage
# =============================================================================
FROM alpine:3.21

# =============================================================================
# TelemetryFlow Metadata Labels (OCI Image Spec)
# =============================================================================
LABEL org.opencontainers.image.title="TelemetryFlow Operator"
LABEL org.opencontainers.image.description="TelemetryFlow Platform Observability - Kubernetes Operator for managing TelemetryFlow deployments"
LABEL org.opencontainers.image.version="1.4.0"
LABEL org.opencontainers.image.vendor="Telemetri Data Indonesia"
LABEL org.opencontainers.image.authors="TelemetryFlow <support@telemetryflow.id>"
LABEL org.opencontainers.image.url="https://telemetryflow.id"
LABEL org.opencontainers.image.documentation="https://docs.telemetryflow.id"
LABEL org.opencontainers.image.source="https://github.com/telemetryflow/telemetryflow-deployment"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.base.name="alpine:3.21"
LABEL io.telemetryflow.product="TelemetryFlow Platform"
LABEL io.telemetryflow.component="telemetryflow-operator"
LABEL io.telemetryflow.platform="CEOP"
LABEL io.telemetryflow.maintainer="TelemetryFlow"

WORKDIR /

RUN apk upgrade --no-cache && \
    apk add --no-cache dumb-init wget ca-certificates tzdata && \
    rm -rf /var/cache/apk/*

RUN addgroup -g 10001 -S operator && \
    adduser -S operator -u 10001 -G operator

COPY --from=builder /manager /manager
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

RUN chown operator:operator /manager

USER operator

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8081/healthz || exit 1

ENTRYPOINT ["dumb-init", "--"]

CMD ["/manager"]
