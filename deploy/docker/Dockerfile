# BFE Application Image
# Build bfe application image based on base image with conf-agent
ARG BASE_IMAGE=bfe-base:debug
FROM --platform=${BUILDPLATFORM} golang:1.22.2-alpine3.19 AS build

ARG TARGETARCH
ARG TARGETOS

WORKDIR /build
COPY . .

# Build bfe
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -ldflags "-X main.version=$(cat VERSION)" -o bfe

# Final image
FROM ${BASE_IMAGE}

# Copy bfe binary and configuration from build stage
COPY --from=build /build/bfe /home/work/bfe/bin/bfe
COPY --from=build /build/conf /home/work/bfe/conf/

# Copy startup script
COPY deploy/docker/entrypoint.sh /home/work/entrypoint.sh
RUN chmod +x /home/work/entrypoint.sh

# Expose ports
EXPOSE 8080 8443 8421

WORKDIR /home/work

# Use startup script to launch both bfe and conf-agent
# The script will:
# 1. Start conf-agent in background (working directory: /home/work/conf-agent/)
# 2. Start bfe in foreground (working directory: /home/work/bfe/bin/)
CMD ["/home/work/entrypoint.sh"]
