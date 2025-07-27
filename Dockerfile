####################################################################################################
## Builder
####################################################################################################
FROM rust:1.74.0-slim AS builder

RUN rustup target add x86_64-unknown-linux-musl \
    && apt update \
    && apt install -y musl-tools musl-dev \
    && apt clean \
    && rm -rf /var/lib/apt/lists/* \
    && update-ca-certificates

ENV USER=nfs
ENV UID=10001

RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    "${USER}" \
    && mkdir -p /nfs/data \
    && chown -R nfs:nfs /nfs/data


WORKDIR /nfs

COPY Cargo.toml Cargo.lock ./
RUN cargo fetch --target x86_64-unknown-linux-musl
COPY ./ .
RUN cargo build --target x86_64-unknown-linux-musl --release \
    && strip target/x86_64-unknown-linux-musl/release/nfs_server

####################################################################################################
## Final image
####################################################################################################
FROM scratch

# Import from builder.
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

WORKDIR /nfs

# Copy our build
COPY --from=builder /nfs/data /nfs/data
COPY --from=builder /nfs/target/x86_64-unknown-linux-musl/release/nfs_server ./

# 暴露NFS默认端口
EXPOSE 2049

# Use an unprivileged user.
USER nfs:nfs


CMD ["./nfs_server"]