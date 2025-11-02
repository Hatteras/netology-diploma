#!/bin/bash

# Обновляем IP из Terraform
BASTION_IP=$(terraform output -raw bastion_ip 2>/dev/null || echo "")
WEB1_IP=$(terraform output -raw web1_ip 2>/dev/null || echo "")
WEB2_IP=$(terraform output -raw web2_ip 2>/dev/null || echo "")

# Обновляем .ssh/config
cat > ~/.ssh/config << EOF
Host bastion
    HostName $BASTION_IP
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host web1 web2 elasticsearch zabbix kibana
    User ubuntu
    ProxyJump bastion
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

# Удаляем старые записи из known_hosts
ssh-keygen -R "$BASTION_IP" 2>/dev/null || true
ssh-keygen -R "$WEB1_IP" 2>/dev/null || true
ssh-keygen -R "$WEB2_IP" 2>/dev/null || true
ssh-keygen -R web1 2>/dev/null || true
ssh-keygen -R web2 2>/dev/null || true

echo "SSH config и known_hosts обновлены"
echo "  bastion → $BASTION_IP"
echo "  web1    → $WEB1_IP"
echo "  web2    → $WEB2_IP"