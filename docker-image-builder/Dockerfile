FROM debian:bullseye-slim

RUN sed -i -e's/ main/ main contrib non-free/g' /etc/apt/sources.list

RUN apt-get update
RUN apt-get --yes upgrade
RUN apt-get install --yes sudo

COPY packages.txt .
COPY install_packages.sh .
RUN ./install_packages.sh

COPY users.csv .
COPY install_users.sh .
RUN ./install_users.sh

RUN echo 'remote    ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
RUN touch /home/remote/.sudo_as_admin_successful
RUN echo 'Defaults  lecture="never"' >> /etc/sudoers

USER remote

COPY install_net-snmp.sh .
RUN ./install_net-snmp.sh

COPY install_fw-suite.sh .
RUN ./install_fw-suite.sh

USER root
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*

EXPOSE 22/tcp
EXPOSE 80/tcp

ENTRYPOINT service ssh restart && bash
