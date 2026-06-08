ARG VERSION=0.7.0
ARG KUBEARCHINSPECT_VERSION=0.7.0

# --- Download stage ---
FROM alpine:3.19 AS downloader
ARG VERSION
ARG KUBEARCHINSPECT_VERSION=0.7.0
ARG TARGETOS=linux
ARG TARGETARCH=arm64

RUN apk add --no-cache wget tar ca-certificates

RUN OS=$(echo "${TARGETOS}" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}') \
    && wget -qO /tmp/kubearchinspect.tar.gz \
    "https://github.com/ArmDeveloperEcosystem/kubearchinspect/releases/download/v${KUBEARCHINSPECT_VERSION}/kubearchinspect_${OS}_${TARGETARCH}.tar.gz" \
    && tar xz -f /tmp/kubearchinspect.tar.gz -C /tmp/ \
    && chmod +x /tmp/kubearchinspect

# --- Final stage ---
FROM alpine:3.19
ARG VERSION

RUN apk add --no-cache ca-certificates \
    && addgroup -S kubearchinspect \
    && adduser -S -G kubearchinspect kubearchinspect

COPY --from=downloader /tmp/kubearchinspect /usr/local/bin/kubearchinspect

USER kubearchinspect

LABEL org.opencontainers.image.title="kubearchinspect" \
      org.opencontainers.image.description="Check if container images in a Kubernetes cluster have arm64 architecture support" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.source="https://github.com/ArmDeveloperEcosystem/kubearchinspect"

ENTRYPOINT ["kubearchinspect"]