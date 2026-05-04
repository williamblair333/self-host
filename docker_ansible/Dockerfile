FROM debian:11-slim

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get --quiet --quiet --yes update
RUN apt-get --quiet --quiet --yes --no-install-recommends \
    --option "DPkg::Options::=--force-confold" \
    --option "DPkg::Options::=--force-confdef" \
    install apt-utils ca-certificates curl python3-pip liblinux-usermod-perl passwd ssl
RUN apt-get --quiet --quiet --yes autoremove
RUN apt-get --quiet --quiet --yes clean
RUN rm -rf /var/lib/apt/lists/* 1>/dev/null

RUN useradd -m -s /bin/bash "ansible" \
    && echo ""ansible":"ansible"" | chpasswd \
    && /usr/sbin/usermod -aG sudo "ansible"

RUN mkdir /etc/ansible
USER ansible

WORKDIR /home/ansible
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
RUN python3 get-pip.py --user
RUN python3 -m pip install --user ansible-core==2.13
RUN python3 -m pip install --user argcomplete

USER ansible
WORKDIR /home/ansible/.local/bin
RUN ./activate-global-python-argcomplete --user
RUN ./ansible --version

#ENV PATH="$PATH:/home/ansible/.local/bin"
ENV PATH="$PATH:/home/ansible/.local/bin:/home/ansible/.ansible"

#CMD ["sh", "./ansible"]
#use this to run container forever if you need to troubleshoot
#this should be just fine for ansible too
CMD exec /bin/sh -c "trap : TERM INT; (while true; do sleep 1000; done) & wait"
