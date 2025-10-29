# Дипломный проект: Отказоустойчивая инфраструктура для сайта в Yandex Cloud

## Описание проекта
Данный дипломный проект направлен на создание отказоустойчивой инфраструктуры для статичного сайта, размещённого в Yandex Cloud.
Инфраструктура включает:
- Веб-серверы (Nginx) в разных зонах, без внешних IP, с доступом через Application Load Balancer.
- Мониторинг с помощью Zabbix (метрики: CPU, RAM, диск, сеть, HTTP).
- Сбор логов через Filebeat в Elasticsearch, визуализация в Kibana.
- Резервное копирование дисков (ежедневные snapshots, TTL 7 дней).
- Сеть: VPC с публичной и приватными подсетями, bastion host, NAT-шлюз.

Инфраструктура разворачивается с помощью **Terraform** и **Ansible**. Все ВМ используют минимальные конфигурации (2 ядра 20% Intel Ice Lake, 2-4 ГБ RAM, 10 ГБ HDD, прерываемые на этапе разработки).

Работа разбита на этапы для простоты повторения (в случае необходимости) и документирования.

<details>

<summary> Этап 1. Подготовка </summary>

На данном этапе проводится подготовка к развертыванию инфраструктуры:
1. **Настроен аккаунт Yandex Cloud**:
  - Создан сервисный аккаунт с ролью `editor`.
  - Сгенерирован ключ для Terraform (хранится локально, не в Git).
  - Установлен и протестирован Yandex Cloud CLI (`yc init`, `yc compute instance list`).
2. **Установлены инструменты**:
  - Terraform (1.13.4-1) для управления инфраструктурой:
```bash
sudo apt update && sudo apt install -y gnupg software-properties-common
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update
sudo apt install terraform -y
terraform -v
```
  - Ansible (2.16.3) для конфигурации ВМ:
```bash
sudo apt update
sudo apt install ansible -y
ansible --version
```
  - Docker (28.5.1) для локального тестирования ELK Stack; после установки необходимо перелогиниться для применения группы docker:
```bash
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo groupadd docker
sudo usermod -aG docker $USER
```
  - Git (2.43.0)
```bash
sudo apt install git -y
git --version
```
3. **Создан SSH-ключ**:
  - Сгенерирован ключ `rsa` (`~/.ssh/id_rsa.pub`) для доступа к ВМ.
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```
4. **Настроено безопасное хранение секретов**:
  - Создан файл ~/.yc/key.json, хранящий ключ Yandex Cloud, файл добавлен в CLI:
```bash
yc config set service-account-key ~/.yc/key.json
```
5. **Настроены переменные окружения для Terraform**:
  - Получены значения переменных:
```bash
yc iam create-token
yc config get cloud-id
yc config get folder-id
```
  - Переменные добавлены в ~/.bashrc:
```bash
export YC_TOKEN="your-token-here"
export YC_CLOUD_ID="your-cloud-id-here"
export YC_FOLDER_ID="your-folder-id-here"
```
1. **Проведено первичное тестирование**
  - Доступ к Yandex Cloud:
```bash
yc compute instance list
```
Вывод:
```
+----+------+---------+--------+-------------+-------------+
| ID | NAME | ZONE ID | STATUS | EXTERNAL IP | INTERNAL IP |
+----+------+---------+--------+-------------+-------------+
+----+------+---------+--------+-------------+-------------+
```
  - Работа Terraform:
```bash
terraform init
```
Вывод:
```
Terraform initialized in an empty directory!

The directory has no Terraform configuration files. You may begin working
with Terraform immediately by creating Terraform configuration files.
```
  - Работа Ansible:
```bash
ansible localhost -m ping
```
Вывод:
```
[WARNING]: No inventory was parsed, only implicit localhost is available
localhost | SUCCESS => {
  "changed": false,
  "ping": "pong"
}
```
  - Работа Docker:
```bash
yc iam create-token
yc config get cloud-id
yc config get folder-id
```
Вывод:
```
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
17eec7bbc9d7: Pull complete 
Digest: sha256:56433a6be3fda188089fb548eae3d91df3ed0d6589f7c2656121b911198df065
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.

 To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (amd64)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/
```

</details>

<details>

<summary> Этап 2: Настройка сети и групп безопасности </summary>

На данном этапе проводится настройка провайдера, развёртывыние сетей, Security Groups и NAT.
Настройка происходит путём редактирования соответствующих файлов для Terraform:

1. **Фиксируем версии и настраиваем провайдера**
  - versions.tf:
```hcl
terraform {
  required_version = ">= 1.13.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.168.0"
    }
  }
}
```
  - providers.tf:
```hcl
provider "yandex" {
  service_account_key_file = pathexpand("~/.yc/key.json") # Авторизованный ключ
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = "ru-central1-a"
}
```
  - terraform.tfvars (добавить валидные значения):
```bash
yc_cloud_id  = "..."
yc_folder_id = "..."
my_ip        = "..."
```
2. **Определяем переменные**:
  - variables.tf:

```hcl
variable "yc_cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "yc_folder_id" {
  description = "Yandex Folder ID"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "diploma-vpc"
}

variable "my_ip" {
  description = "My public IP for SSH access"
  type        = string
  sensitive   = true
}

variable "public_subnet_cidr" {
  description = "CIDR for public subnet"
  type        = string
  default     = "192.168.1.0/24"
}

variable "private_subnet_a_cidr" {
  description = "CIDR for private subnet in zone a"
  type        = string
  default     = "192.168.2.0/24"
}

variable "private_subnet_b_cidr" {
  description = "CIDR for private subnet in zone b"
  type        = string
  default     = "192.168.3.0/24"
}
```
3. **Настраиваем VPC и подсети**
  - networks.tf:
```hcl
# VPC
resource "yandex_vpc_network" "diploma" {
  name = var.vpc_name
}

# Публичная подсеть (для Zabbix, Kibana, Bastion, ALB)
resource "yandex_vpc_subnet" "public" {
  name           = "public-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.diploma.id
  v4_cidr_blocks = [var.public_subnet_cidr]
}

# Приватные подсети
resource "yandex_vpc_subnet" "private_a" {
  name           = "private-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.diploma.id
  v4_cidr_blocks = [var.private_subnet_a_cidr]
  route_table_id = yandex_vpc_route_table.nat.id
}

resource "yandex_vpc_subnet" "private_b" {
  name           = "private-subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.diploma.id
  v4_cidr_blocks = [var.private_subnet_b_cidr]
  route_table_id = yandex_vpc_route_table.nat.id
}
```
4. **Настраиваем NAT-шлюз и таблицу маршрутов**
  - nat.tf:
```hcl
# NAT Instance (минимальная ВМ)
resource "yandex_compute_instance" "nat" {
  name        = "nat-gateway"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = "fd851hdolfjh210g3c17"  # NAT-instance image (Yandex)
      size     = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.public.id
    nat       = true
  }

  metadata = {
    user-data = file("${path.module}/cloud-init-nat.yml")
  }
}

# Маршрутная таблица
resource "yandex_vpc_route_table" "nat" {
  name       = "nat-route-table"
  network_id = yandex_vpc_network.diploma.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = yandex_compute_instance.nat.network_interface.0.ip_address
  }
}
```
  - cloud-init-nat.yml:
```yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp4-overrides:
        use-dns: false
runcmd:
  - sysctl -w net.ipv4.ip_forward=1
  - iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
  - echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
```
5. **Настраиваем Security Groups**
  - security-groups.tf:
```hcl
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
    protocol          = "tcp"
    description       = "HTTP from ALB"
    security_group_id = yandex_vpc_security_group.alb.id
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
    description    = "Zabbix Server from agents"
    v4_cidr_blocks = [
      var.private_subnet_a_cidr,
      var.private_subnet_b_cidr
    ]
    port           = 10051
  }

  ingress {
    protocol       = "tcp"
    description    = "Web UI"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
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
    description    = "Kibana UI"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 5601
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
    protocol       = "tcp"
    description    = "HTTP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  egress {
    protocol       = "any"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
```
6. **Определяем выходные переменные**
  - outputs.tf:
```hcl
output "vpc_id" {
  value = yandex_vpc_network.diploma.id
}

output "public_subnet_id" {
  value = yandex_vpc_subnet.public.id
}

output "private_subnet_a_id" {
  value = yandex_vpc_subnet.private_a.id
}

output "private_subnet_b_id" {
  value = yandex_vpc_subnet.private_b.id
}

output "nat_ip" {
  value = yandex_compute_instance.nat.network_interface.0.nat_ip_address
}
```
7. **Обновляем .gitignore**
  - .gitignore
```gitignore
# Terraform
.terraform/
.terraform.lock.hcl
terraform.tfstate
terraform.tfstate.backup
terraform.tfvars

# Secrets
*.pem
*.key
*.json

# Локальные файлы
*.log
*.tmp
```
8. **Деплой и тестирование**
  - Инициализация, планирование и деплой:
```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```
Вывод:
```bash
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.

Outputs:

nat_ip = "158.160.101.53"
private_subnet_a_id = "e9barqde95t2rcjf8uat"
private_subnet_b_id = "e2l2sebcm20e81l21k7f"
public_subnet_id = "e9blrcb6v4jh4ueup7es"
vpc_id = "enpm1n1vj6mnoir9s07g"
```
  - Проверка VPC и подсетей:
```bash
yc vpc network list
yc vpc subnet list
```
Вывод:
```
+----------------------+-------------+
|          ID          |    NAME     |
+----------------------+-------------+
| enpm1n1vj6mnoir9s07g | diploma-vpc |
+----------------------+-------------+

+----------------------+------------------+----------------------+----------------------+---------------+------------------+
|          ID          |       NAME       |      NETWORK ID      |    ROUTE TABLE ID    |     ZONE      |      RANGE       |
+----------------------+------------------+----------------------+----------------------+---------------+------------------+
| e2l2sebcm20e81l21k7f | private-subnet-b | enpm1n1vj6mnoir9s07g | enp4qmo8v4utndon8p24 | ru-central1-b | [192.168.3.0/24] |
| e9barqde95t2rcjf8uat | private-subnet-a | enpm1n1vj6mnoir9s07g | enp4qmo8v4utndon8p24 | ru-central1-a | [192.168.2.0/24] |
| e9blrcb6v4jh4ueup7es | public-subnet    | enpm1n1vj6mnoir9s07g |                      | ru-central1-a | [192.168.1.0/24] |
+----------------------+------------------+----------------------+----------------------+---------------+------------------+
```
  - Проверка NAT-gateway:
```bash
yc compute instance list
```
Вывод:
```
+----------------------+-------------+---------------+---------+----------------+--------------+
|          ID          |    NAME     |    ZONE ID    | STATUS  |  EXTERNAL IP   | INTERNAL IP  |
+----------------------+-------------+---------------+---------+----------------+--------------+
| fhmmatrfpg5g7gkst11p | nat-gateway | ru-central1-a | RUNNING | 158.160.101.53 | 192.168.1.33 |
+----------------------+-------------+---------------+---------+----------------+--------------+
```
  - Проверка маршрутной таблицы:
```bash
yc vpc route-table list
yc vpc route-table get nat-route-table
```
Вывод:
```
+----------------------+-----------------+-------------+----------------------+
|          ID          |      NAME       | DESCRIPTION |      NETWORK-ID      |
+----------------------+-----------------+-------------+----------------------+
| enp4qmo8v4utndon8p24 | nat-route-table |             | enpm1n1vj6mnoir9s07g |
+----------------------+-----------------+-------------+----------------------+

id: enp4qmo8v4utndon8p24
folder_id: b1gh19tdmqdb1m0tod0r
created_at: "2025-10-28T19:31:29Z"
name: nat-route-table
network_id: enpm1n1vj6mnoir9s07g
static_routes:
  - destination_prefix: 0.0.0.0/0
    next_hop_address: 192.168.1.33
```
  - Проверка Security Groups:
```bash
yc vpc security-group list
```
Вывод:
```
+----------------------+---------------------------------+--------------------------------+----------------------+
|          ID          |              NAME               |          DESCRIPTION           |      NETWORK-ID      |
+----------------------+---------------------------------+--------------------------------+----------------------+
| enp618o0ajocjd9schrj | zabbix-sg                       |                                | enpm1n1vj6mnoir9s07g |
| enp7pm0aca0g0aij2mbs | default-sg-enpm1n1vj6mnoir9s07g | Default security group for     | enpm1n1vj6mnoir9s07g |
|                      |                                 | network                        |                      |
| enpb4o34q30h2e2s91he | web-sg                          |                                | enpm1n1vj6mnoir9s07g |
| enpdkuonccdqsn7h3i3q | elasticsearch-sg                |                                | enpm1n1vj6mnoir9s07g |
| enphj4jrom4982j7tqko | bastion-sg                      |                                | enpm1n1vj6mnoir9s07g |
| enpldnhd3l1oi4ngae7v | alb-sg                          |                                | enpm1n1vj6mnoir9s07g |
| enpp5sain0s62q7hdju1 | kibana-sg                       |                                | enpm1n1vj6mnoir9s07g |
+----------------------+---------------------------------+--------------------------------+----------------------+
```

</details>

<details>

<summary> Этап 3: Развертывание виртуальных машин </summary>

На данном этапе проводится настройка виртуальных машин и назначение им сетевых расположений, созданных ранее.
Настройка происходит путём редактирования соответствующих файлов для Terraform:
1. **Определяем параметры виртуальных машин**
  - instances.tf:
```hcl
# Образ
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

# Bastion
resource "yandex_compute_instance" "bastion" {
  name        = "bastion"
  hostname    = "bastion"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.bastion.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  scheduling_policy {
    preemptible = true
  }

  allow_stopping_for_update = true
}

# Web-серверы
resource "yandex_compute_instance" "web" {
  for_each = {
    "web1" = { zone = "ru-central1-a", subnet = yandex_vpc_subnet.private_a.id }
    "web2" = { zone = "ru-central1-b", subnet = yandex_vpc_subnet.private_b.id }
  }

  name        = each.key
  hostname    = each.key
  platform_id = "standard-v3"
  zone        = each.value.zone

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
    }
  }

  network_interface {
    subnet_id          = each.value.subnet
    security_group_ids = [yandex_vpc_security_group.web.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  scheduling_policy {
    preemptible = true
  }

  allow_stopping_for_update = true
}

# Zabbix
resource "yandex_compute_instance" "zabbix" {
  name        = "zabbix"
  hostname    = "zabbix"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.zabbix.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  scheduling_policy {
    preemptible = true
  }

  allow_stopping_for_update = true
}

# Elasticsearch
resource "yandex_compute_instance" "elasticsearch" {
  name        = "elasticsearch"
  hostname    = "elasticsearch"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    security_group_ids = [yandex_vpc_security_group.elasticsearch.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  scheduling_policy {
    preemptible = true
  }

  allow_stopping_for_update = true
}

# Kibana
resource "yandex_compute_instance" "kibana" {
  name        = "kibana"
  hostname    = "kibana"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.kibana.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  scheduling_policy {
    preemptible = true
  }

  allow_stopping_for_update = true
}
```
2. **Небольшое дополнение для уменьшения стоимости при тестировании**
  - nat.tf:
```hcl
scheduling_policy {
    preemptible = true
  }
```
3. **Добавление выходных переменных**
  - outputs.tf (добавлено):
```hcl
output "bastion_ip" {
  value       = yandex_compute_instance.bastion.network_interface.0.nat_ip_address
  description = "Public IP of bastion host"
}

output "web1_ip" {
  value = yandex_compute_instance.web["web1"].network_interface.0.ip_address
}

output "web2_ip" {
  value = yandex_compute_instance.web["web2"].network_interface.0.ip_address
}

output "elasticsearch_ip" {
  value = yandex_compute_instance.elasticsearch.network_interface.0.ip_address
}
```
4. **Скрипт для локального тестирования и упрощения доступа к Bastion и другим ресурсам по ssh.**
  - bastion-config.sh:
```bash
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
```

5. **Деплой и тестирование**
  - Инициализация, планирование и деплой:
```bash
terraform fmt
terraform validate
terraform plan
terraform apply
./bastion-config.sh
```
Вывод:
```bash
Apply complete! Resources: 18 added, 0 changed, 0 destroyed.

Outputs:

bastion_ip = "158.160.111.52"
elasticsearch_ip = "192.168.2.31"
nat_ip = "158.160.54.161"
private_subnet_a_id = "e9bcifv6q670jglbajeq"
private_subnet_b_id = "e2l8j6uo7tkl09t3qcu9"
public_subnet_id = "e9bfean41vsnii4ab4p3"
vpc_id = "enpb9gdfap5hcrtqn16p"
web1_ip = "192.168.2.35"
web2_ip = "192.168.3.28"

Конфигурация SSH обновлена:
  bastion   → 158.160.111.52
  web1      → 192.168.2.35
  web2      → 192.168.3.28
  elasticsearch → 192.168.2.31
```
  - Проверка виртуальных машин:
```bash
yc compute instance list
```
Вывод:
```bash
+----------------------+---------------+---------------+---------+----------------+--------------+
|          ID          |     NAME      |    ZONE ID    | STATUS  |  EXTERNAL IP   | INTERNAL IP  |
+----------------------+---------------+---------------+---------+----------------+--------------+
| epdiu875v5d77s5io5oe | web2          | ru-central1-b | RUNNING |                | 192.168.3.28 |
| fhm80u89i2cupbfpkdob | web1          | ru-central1-a | RUNNING |                | 192.168.2.35 |
| fhmaqho69ni2r541m6ku | bastion       | ru-central1-a | RUNNING | 158.160.111.52 | 192.168.1.24 |
| fhmbf2vovfd18ajsb5fn | elasticsearch | ru-central1-a | RUNNING |                | 192.168.2.31 |
| fhmcn5jrvdbdgudn914o | kibana        | ru-central1-a | RUNNING | 158.160.106.99 | 192.168.1.21 |
| fhmehvfob3qiqp5mg4m1 | nat-gateway   | ru-central1-a | RUNNING | 158.160.54.161 | 192.168.1.10 |
| fhms9f2ve6rteb84btnv | zabbix        | ru-central1-a | RUNNING | 158.160.49.47  | 192.168.1.35 |
+----------------------+---------------+---------------+---------+----------------+--------------+
```
  - Проверка доступа по SSH:
```bash
ssh web1 whoami
```
Вывод:
```bash
ubuntu
```
  - Проверка NAT из приватной сети:
```bash
ssh web2 curl -s ifconfig.me
```
Вывод:
```bash
158.160.54.161
```

</details>