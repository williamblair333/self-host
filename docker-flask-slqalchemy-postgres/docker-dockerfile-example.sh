#!/bin/bash
#################################################################################

touch Dockerfile
touch .dockerignore
#https://docs.docker.com/develop/develop-images/dockerfile_best-practices/

#create the configuration
cat >> debian_11_base <<EOL
FROM debian:11
RUN apt-get update
RUN apt-get install -y postgresql postgresql-client
CMD ["ls"]
EOL

#build the image
#docker build -t \
#    new_docker_image_name \
#    PATH_to_Dockerfile

sudo docker build \
    -t debian_11_base/man:v2 \
    /var/lib/docker/images/debian_11_base

#build the container
#docker run \
#    -d --name container_name \
#    image_name

sudo docker run \
    -d --name debian_11_postgresql \
    debian_11_base

sudo docker run -d \
    --name postgres_13_debian_11 \
    /var/lib/docker/images/debian_11_base/man:v2
#################################################################################
