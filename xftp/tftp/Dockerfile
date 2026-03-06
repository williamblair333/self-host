FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    tftpd-hpa \
    && rm -rf /var/lib/apt/lists/*
EXPOSE 69/udp
ENTRYPOINT ["in.tftpd", "-L", "--secure", "--create", "/files"]
