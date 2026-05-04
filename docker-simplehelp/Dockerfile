FROM debian:11-slim

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get --quiet --quiet --yes update
RUN apt-get --quiet --quiet --yes --no-install-recommends \
    --option "DPkg::Options::=--force-confold" \
    --option "DPkg::Options::=--force-confdef" \
    install apt-utils ca-certificates wget
RUN apt-get --quiet --quiet --yes autoremove
RUN apt-get --quiet --quiet --yes clean
RUN rm -rf /var/lib/apt/lists/* 1>/dev/null

WORKDIR /opt
#Uncomment next line for new installations
RUN wget https://simple-help.com/releases/SimpleHelp-linux-amd64.tar.gz
#RUN wget https://simple-help.com/releases/5.2.17/SimpleHelp-linux-amd64.tar.gz
#COPY ./SimpleHelp-linux-amd64.tar.gz .

#RUN cd /opt && tar -xzf SimpleHelp-linux-amd64.tar.gz && rm SimpleHelp-linux-amd64.tar.gz
RUN tar -xzf SimpleHelp-linux-amd64.tar.gz && rm SimpleHelp-linux-amd64.tar.gz

WORKDIR /opt/SimpleHelp

RUN sed -i 's/&//g' serverstart.sh

CMD ["sh", "serverstart.sh"]
#use this to run container forever if you need to troubleshoot
#CMD exec /bin/sh -c "trap : TERM INT; (while true; do sleep 1000; done) & wait"
