FROM debian:bookworm-slim

RUN apt-get --quiet --quiet --yes update 1>/dev/null
RUN apt-get --quiet --quiet --yes --no-install-recommends \
    --option "DPkg::Options::=--force-confold" \
    --option "DPkg::Options::=--force-confdef" \
    install nano postfix mailutils rsyslog 1>/dev/null
RUN rm --recursive --force /var/lib/apt/lists/* 1>/dev/null    

EXPOSE 25

# Start Postfix service
CMD ["postfix", "start-fg"]
