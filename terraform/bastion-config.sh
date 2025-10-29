#!/bin/bash

BASTION_IP=$(terraform output -raw bastion_ip)
WEB1_IP=$(terraform output -raw web1_ip)
WEB2_IP=$(terraform output -raw web2_ip)
ELASTIC_IP=$(terraform output -raw elasticsearch_ip)

cat > ~/.ssh/config << EOF
Host bastion
    HostName $BASTION_IP
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no

Host web1
    HostName $WEB1_IP
    User ubuntu
    ProxyJump bastion
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no

Host web2
    HostName $WEB2_IP
    User ubuntu
    ProxyJump bastion
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no

Host elasticsearch
    HostName $ELASTIC_IP
    User ubuntu
    ProxyJump bastion
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
EOF

echo "Конфигурация SSH обновлена:"
echo "  bastion   → $BASTION_IP"
echo "  web1      → $WEB1_IP"
echo "  web2      → $WEB2_IP"
echo "  elasticsearch → $ELASTIC_IP"