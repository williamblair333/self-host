FROM jenkins/jenkins:jdk11

USER root

RUN apt-get update && apt-get --yes install docker.io docker-compose
RUN echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config

EXPOSE 8080
EXPOSE 50000
