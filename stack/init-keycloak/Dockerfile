FROM ghcr.io/opentofu/opentofu:1.13.5-minimal@sha256:ca43a94b18b8d962299d110822af56a03192fd8ea74d3d7358aaee3f93ed3d90 AS tofu

FROM alpine:3.24.2@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

# Copy the tofu binary from the minimal image
COPY --from=tofu /usr/local/bin/tofu /usr/local/bin/tofu

# Add curl and jq
RUN apk add --no-cache bash curl jq

# Copy scripts
COPY entrypoint.sh /bin
COPY update_roles_scope.sh /bin
