#!/usr/bin/env bash

# Kill and remove the container
docker kill rhel-ssh
docker rm rhel-ssh

# Remove the keys dir
rm -f ./keys/*
rmdir ./keys

# Remove localhost from known_hosts to prevent strict host checking from
# preventing subsequent runs
ssh-keygen -f "/home/se/.ssh/known_hosts" -R "localhost"
