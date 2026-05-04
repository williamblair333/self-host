#!/bin/bash
#################################################################################
#
#Run example: N/A
#File:        docker-postgres-setup.sh
#Date:        2022FEB11
#Author:      William Blair
#Contact:     williamblair333@gmail.com
#Tested on:   Debian 11
#To test:     Ubuntu 14+
#
#This script is intended to do the following:
#
#- use docker to create a container and volume for postgres which in turn will
#- provide a database server for flask, ssms and anything else 
#- This is also provided as a reference and is a work in progress
#
#################################################################################
#################################################################################
#docker container, volume and everything else location..
#/var/lib/docker/
#some useful commands..
#docker info
#sudo docker container ls --all
#sudo docker volume ls
#sudo docker container stop container_id
#sudo docker container start container_id
#'attach' to the container
#sudo docker exec -ti container_id bash
#################################################################################
 
#set variables for the container and volume
 
volume=postgres13-bullseye-training
db_name=$volume
db_user='postgres'
db_password='YourStrong@Passw0rd'
pgdata=/var/lib/postgresql/data/pgdata
pgvolume=/var/lib/postgresql/data
port_in=5432
port_out=5432
image=postgres:13-bullseye
#################################################################################
 
#setup container and volume
#pull the latest postgres image.  Anything after the colon is a tag, which is
#typically a variation of the the standard image.
#sudo docker pull postgres:latest
sudo docker pull postgres:13-bullseye
 
#use volumes to persist data https://docs.docker.com/storage/volumes/
sudo docker volume create $volume
 
#create the container
sudo docker run \
    -d \
    --name $db_name \
    -e POSTGRES_USER=$db_user \
    -e POSTGRES_PASSWORD=$db_password \
    -e PGDATA=$pgdata \
    -v $volume:$pgvolume \
    -p $port_in:$port_out \
    -it $image
#################################################################################
 
#troubleshooting to quickly remove container and its associated volume
#sudo docker container stop container_id && \
#    sudo docker container_id && \
#    sudo docker volume rm $volume
#################################################################################
