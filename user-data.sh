#!/bin/bash
sudo apt update -y

PUBLIC_KEY="{{ ssh_key_content }}"

HOME_DIR="/home/ubuntu"
USER="ubuntu"

mkdir -p $HOME_DIR/.ssh

echo "$PUBLIC_KEY" >> $HOME_DIR/.ssh/authorized_keys

chmod 700 $HOME_DIR/.ssh
chmod 600 $HOME_DIR/.ssh/authorized_keys
chown -R $USER:$USER $HOME_DIR/.ssh

sudo apt install openjdk-8-jdk -y
sudo apt install python3 -y
