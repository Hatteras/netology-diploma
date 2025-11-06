#!/bin/bash

WEB1_IP=$(terraform output -raw web1_ip)
WEB2_IP=$(terraform output -raw web2_ip)
ELASTIC_IP=$(terraform output -raw elasticsearch_ip)
KIBANA_IP=$(terraform output -raw kibana_ip)
BASTION_IP=$(terraform output -raw bastion_ip)
ZABBIX_IP=$(terraform output -raw zabbix_ip)

cat > ~/netology-diploma/ansible/inventory.ini << EOF

[public]
zabbix ansible_host=$ZABBIX_IP
kibana ansible_host=$KIBANA_IP
bastion ansible_host=$BASTION_IP

[public:vars]
ansible_user=ubuntu
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

[private_servers]
elasticsearch ansible_host=$ELASTIC_IP

[private_servers:vars]
ansible_user=ubuntu
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyJump=bastion'

[webservers]
web1 ansible_host=$WEB1_IP
web2 ansible_host=$WEB2_IP

[webservers:vars]
ansible_user=ubuntu
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyJump=bastion'
EOF