#!/bin/bash

BASTION_IP=$(terraform output -raw bastion_ip)
WEB1_IP=$(terraform output -raw web1_ip)
WEB2_IP=$(terraform output -raw web2_ip)
ELASTIC_IP=$(terraform output -raw elasticsearch_ip)
KIBANA_IP=$(terraform output -raw kibana_ip)
ZABBIX_IP=$(terraform output -raw zabbix_ip)

cat > ~/.ssh/config << EOF
# Bastion
Host bastion
    HostName $BASTION_IP
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

# Private servers (ProxyJump bastion)
Host web1
    HostName $WEB1_IP
    User ubuntu
    ProxyJump bastion
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

# Private servers (ProxyJump bastion)
Host web2
    HostName $WEB2_IP
    User ubuntu
    ProxyJump bastion
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

# Private servers (ProxyJump bastion)
Host elasticsearch
    HostName $ELASTIC_IP
    User ubuntu
    ProxyJump bastion
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

# Public servers (direct SSH)
Host kibana
    HostName $KIBANA_IP
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host zabbix
    HostName $ZABBIX_IP
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

ssh-keygen -R "$BASTION_IP" 2>/dev/null || true
ssh-keygen -R "$WEB1_IP" 2>/dev/null || true
ssh-keygen -R "$WEB2_IP" 2>/dev/null || true
ssh-keygen -R "$ELASTIC_IP" 2>/dev/null || true
ssh-keygen -R "$KIBANA_IP" 2>/dev/null || true
ssh-keygen -R "$ZABBIX_IP" 2>/dev/null || true