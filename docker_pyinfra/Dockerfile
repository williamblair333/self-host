FROM debian:11-slim

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get --quiet --quiet --yes update
RUN apt-get --quiet --quiet --yes --no-install-recommends     --option "DPkg::Options::=--force-confold"     --option "DPkg::Options::=--force-confdef"     install apt-utils ca-certificates curl liblinux-usermod-perl python3-pip passwd ssh python3-venv
RUN apt-get --quiet --quiet --yes autoremove
RUN apt-get --quiet --quiet --yes clean
RUN rm -rf /var/lib/apt/lists/* 1>/dev/null

RUN useradd -m -s /bin/bash "pyinfra"     && echo ""pyinfra":"pyinfra"" | chpasswd     && /usr/sbin/usermod -aG sudo "pyinfra"

ENV PATH="/home/bill/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games:/sbin:/usr/sbin:/home/pyinfra/.local/bin:/home/pyinfra/.pyinfra"

USER pyinfra
RUN mkdir -p /home/pyinfra/.local/bin
RUN mkdir -p /home/pyinfra/pyinfra
WORKDIR /home/pyinfra/.local/bin

RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
RUN python3 get-pip.py --user
RUN python3 -m pip install --user argcomplete
RUN python3 -m pip install --user pipx
RUN python3 -m pipx ensurepath
RUN pipx install pyinfra

RUN ./activate-global-python-argcomplete --user

WORKDIR /home/pyinfra/pyinfra

#use this to run container forever if you need to troubleshoot
#this should be just fine for pyinfra too
CMD exec /bin/sh -c "trap : TERM INT; (while true; do sleep 1000; done) & wait"
