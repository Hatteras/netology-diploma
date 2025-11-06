# Бастион-хост: только SSH
resource "yandex_vpc_security_group" "bastion" {
  name       = "bastion-sg"
  network_id = yandex_vpc_network.diploma.id

  ingress {
    protocol       = "tcp"
    description    = "SSH"
    v4_cidr_blocks = [var.my_ip] # Переменная хранится в terraform.tfvars
    port           = 22
  }

  ingress {
    protocol          = "tcp"
    description       = "Zabbix Agent"
    security_group_id = yandex_vpc_security_group.zabbix.id
    port              = 10050
  }

  egress {
    protocol       = "any"
    description    = "All outbound"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Веб-серверы
resource "yandex_vpc_security_group" "web" {
  name       = "web-sg"
  network_id = yandex_vpc_network.diploma.id

  ingress {
    protocol          = "any"
    description       = "HTTP from ALB"
    predefined_target = "loadbalancer_healthchecks"
    port              = 80
  }

  ingress {
    protocol          = "tcp"
    description       = "SSH from bastion"
    security_group_id = yandex_vpc_security_group.bastion.id
    port              = 22
  }

  ingress {
    protocol          = "tcp"
    description       = "Zabbix Agent"
    security_group_id = yandex_vpc_security_group.zabbix.id
    port              = 10050
  }

  # Временное правило: позволяет ALB работать.
  # Без него health checks не проходят, несмотря на наличие predefined_target.
  # На реальном проде - найти причину и немедленно заменить на конкретные диапазоны!
  ingress {
    protocol       = "any"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "any"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Zabbix
resource "yandex_vpc_security_group" "zabbix" {
  name       = "zabbix-sg"
  network_id = yandex_vpc_network.diploma.id

  ingress {
    protocol       = "tcp"
    description    = "SSH"
    v4_cidr_blocks = [var.my_ip]
    port           = 22
  }

  ingress {
    protocol    = "tcp"
    description = "Zabbix Server from agents"
    v4_cidr_blocks = [
      var.private_subnet_a_cidr,
      var.private_subnet_b_cidr
    ]
    port = 10051
  }

  ingress {
    protocol       = "tcp"
    description    = "Zabbix Web UI"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 80
    to_port        = 80
  }

  ingress {
    protocol       = "tcp"
    description    = "Zabbix Web UI HTTPS"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 443
    to_port        = 443
  }

  egress {
    protocol       = "any"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Elasticsearch
resource "yandex_vpc_security_group" "elasticsearch" {
  name       = "elasticsearch-sg"
  network_id = yandex_vpc_network.diploma.id

  ingress {
    protocol          = "tcp"
    description       = "SSH from bastion"
    security_group_id = yandex_vpc_security_group.bastion.id
    port              = 22
  }

  ingress {
    protocol          = "tcp"
    description       = "From Kibana"
    security_group_id = yandex_vpc_security_group.kibana.id
    port              = 9200
  }

  ingress {
    protocol          = "tcp"
    description       = "From Filebeat"
    security_group_id = yandex_vpc_security_group.web.id
    port              = 9200
  }

  ingress {
    protocol          = "tcp"
    description       = "Zabbix Agent"
    security_group_id = yandex_vpc_security_group.zabbix.id
    port              = 10050
  }

  egress {
    protocol       = "any"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Kibana
resource "yandex_vpc_security_group" "kibana" {
  name       = "kibana-sg"
  network_id = yandex_vpc_network.diploma.id

  ingress {
    protocol       = "tcp"
    description    = "SSH from user"
    v4_cidr_blocks = [var.my_ip]
    port           = 22
  }

  ingress {
    protocol       = "tcp"
    description    = "Kibana UI"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 5601
  }

  ingress {
    protocol          = "tcp"
    description       = "Zabbix Agent"
    security_group_id = yandex_vpc_security_group.zabbix.id
    port              = 10050
  }

  egress {
    protocol       = "any"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB
resource "yandex_vpc_security_group" "alb" {
  name       = "alb-sg"
  network_id = yandex_vpc_network.diploma.id

  ingress {
    protocol       = "any"
    description    = "HTTP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol          = "any"
    description       = "ALB Health Checks"
    predefined_target = "loadbalancer_healthchecks"
  }

  egress {
    protocol       = "any"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}