FROM ghcr.io/opentofu/opentofu:1.13.10-minimal@sha256:5c6cef27227e50060139fec7122c83d14088b5dd2677162545f0e699e1f6196c AS tofu

FROM alpine:3.24.2@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

# Copy the tofu binary from the minimal image
COPY --from=tofu /usr/local/bin/tofu /usr/local/bin/tofu

# Add curl and jq
RUN apk add --no-cache bash curl jq

# Copy scripts
COPY entrypoint.sh /bin
COPY update_roles_scope.sh /bin
