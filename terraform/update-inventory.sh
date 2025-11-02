#!/bin/bash

WEB1_IP=$(terraform output -raw web1_ip)
WEB2_IP=$(terraform output -raw web2_ip)

cat > ~/netology-diploma/ansible/inventory.ini << EOF
[webservers]
web1 ansible_host=$WEB1_IP
web2 ansible_host=$WEB2_IP

[webservers:vars]
ansible_user=ubuntu
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyJump=bastion'
EOF