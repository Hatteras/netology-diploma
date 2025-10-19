# Дипломный проект: Отказоустойчивая инфраструктура для сайта в Yandex Cloud

## Описание проекта
Данный дипломный проект направлен на создание отказоустойчивой инфраструктуры для статичного сайта, размещённого в Yandex Cloud.
Инфраструктура включает:
- Веб-серверы (Nginx) в разных зонах, без внешних IP, с доступом через Application Load Balancer.
- Мониторинг с помощью Zabbix (метрики USE: CPU, RAM, диск, сеть, HTTP).
- Сбор логов через Filebeat в Elasticsearch, визуализация в Kibana.
- Резервное копирование дисков (ежедневные snapshots, TTL 7 дней).
- Сеть: VPC с публичной и приватными подсетями, bastion host, NAT-шлюз.
- Дополнительно: Instance Group для веб-серверов, разделение Zabbix (Frontend/Server/DB), HTTPS через Yandex Certificate Manager (возможно).

Инфраструктура разворачивается с помощью **Terraform** (для ресурсов Yandex Cloud) и **Ansible** (для настройки ВМ). Все ВМ используют минимальные конфигурации (2 ядра 20% Intel Ice Lake, 2-4 ГБ RAM, 10 ГБ HDD, прерываемые на этапе разработки).

Работа разбита на этапы для простоты повторения (в случае необходимости) и документирования.

## Подготовка
На данном этапе проводится подготовка к развертыванию инфраструктуры:
1. **Настроен аккаунт Yandex Cloud**:
   - Создан сервисный аккаунт с ролью `editor`.
   - Сгенерирован ключ для Terraform (хранится локально, не в Git).
   - Установлен и протестирован Yandex Cloud CLI (`yc init`, `yc compute instance list`).
2. **Установлены инструменты**:
   - Terraform (1.12.2) для управления инфраструктурой.
   - Ansible (2.16.3) для конфигурации ВМ.
3. **Подготовлен статичный сайт**:
   - Папка `site/` содержит файлы: `index.html`, `styles.css`.
   - Сайт протестирован локально с помощью `python3 -m http.server 8000`.
4. **Инициализирован Git-репозиторий**:
   - Создан репозиторий на GitHub.
   - Добавлен `.gitignore` для исключения секретов (токены, SSH-ключи, Terraform state).
   - Создана структура: `ansible/`, `docs/`, `site/`, `terraform/`.
5. **SSH-ключи**:
   - Сгенерирован ключ `ed25519` (`~/.ssh/id_ed25519.pub`) для доступа к ВМ.

**Структура репозитория на данном этапе**
- `ansible/` — Ansible playbooks и inventory для настройки ВМ
  - `hosts.yml` — Пустой
  - `site.yml` — Пустой
- `docs/` — Дополнительная документация и схемы (будут добавлены в случае необходимости)
- `site/` — Статичный сайт
  - `index.html` — Создан элементарный сайт с двумя заголовками
  - `styles.css` — Добавлены стили для текста и background'а
- `terraform/` — Terraform-конфигурации (будут добавлены для VPC, ВМ, ALB и т.д.)
  - `main.tf` — Добавлен блок провайдера Yandex
  - `variables.tf` — Пустой
- `.gitignore` — Исключает секреты и Terraform state

**Содержимое файлов:**

- `index.html`
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Diploma Site</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <h1>Test site for Netology Diploma</h1>
    <p>And this background is light blue. Relaxing, isn't it?</p>
</body>
</html>
```

- `styles.css`
```css
body {
    background-color: lightblue;
    font-family: Arial, sans-serif;
    text-align: center;
    margin: 50px;
}
h1 {
    color: navy;
}
p {
    font-size: 18px;
    color: darkgreen;
}
```

- `main.tf`
```hcl
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}
provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = "ru-central1-a"
}
```

## Этап 1: Настройка сети в Yandex Cloud

На данном этапе создаётся базовая сетевая инфраструктура в Yandex Cloud с использованием Terraform. Выполнены следующие задачи:
1. **VPC и подсети**:
   - Создана сеть VPC (`diploma-vpc`).
   - Настроены подсети:
     - Публичная подсеть (`public-a`) в зоне `ru-central1-a` (CIDR: `10.0.1.0/24`) для bastion, Zabbix Frontend, Kibana и ALB.
     - Приватные подсети (`private-a`, `private-b`) в зонах `ru-central1-a` и `ru-central1-b` (CIDR: `10.0.2.0/24`, `10.0.3.0/24`) для веб-серверов, Elasticsearch и Zabbix Server.
2. **NAT-шлюз**:
   - Настроен managed NAT-шлюз (`diploma-nat`) для исходящего трафика из приватных подсетей.
   - Создана таблица маршрутов (`private-routes`), направляющая трафик `0.0.0.0/0` через NAT для приватных подсетей.
3. **Security Groups**:
   - Настроены группы безопасности для ограничения трафика:
     - `bastion-sg`: Входящий SSH (порт 22) только с указанного IP.
     - `web-sg`: Входящий HTTP (80) от балансировщика, SSH от bastion.
     - `es-sg`: Входящий для Elasticsearch (9200) от Filebeat/Kibana, SSH от bastion.
     - `zabbix-server-sg`: Входящий для Zabbix Server (10051) от агентов/Frontend, SSH от bastion.
     - `zabbix-frontend-sg`: Входящий HTTP/HTTPS (80/443) от мира, SSH от bastion.
     - `kibana-sg`: Входящий для Kibana (5601) от мира, SSH от bastion.
     - Все группы разрешают исходящий трафик через NAT.
4. **Bastion host**:
   - Развёрнута ВМ (`bastion`) в публичной подсети (`ru-central1-a`) с публичным IP.
   - Конфигурация: 2 ядра (20% Intel Ice Lake), 2 ГБ RAM, 10 ГБ HDD, прерываемая.
   - SSH-доступ настроен через публичный ключ (`~/.ssh/id_ed25519.pub`).

**Изменены файлы:**
- `main.tf`
- `variables.tf`

**Добавленый файлы:**
- `terraform.tfvars`
- `outputs.tf`
- `.terraform.lock.hcl` — Создан автоматически после использования команды terraform init

**Содержимое файлов:**
- `main.tf`
```hcl
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      version = "~> 0.165.0"
    }
  }
}
provider "yandex" {
  service_account_key_file = "netology-diploma_authorized_key.json"
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = "ru-central1-a"
}

#VPC
resource "yandex_vpc_network" "main" {
  name = "diploma-vpc"
}

resource "yandex_vpc_subnet" "public_a" {
  name           = "public-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.0.1.0/24"]
}

resource "yandex_vpc_subnet" "private_a" {
  name           = "private-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.0.2.0/24"]
  route_table_id = yandex_vpc_route_table.private_route_table.id
}

resource "yandex_vpc_subnet" "private_b" {
  name           = "private-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.0.3.0/24"]
  route_table_id = yandex_vpc_route_table.private_route_table.id
}

#NAT
resource "yandex_vpc_gateway" "nat_gateway" {
  name = "diploma-nat"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "private_route_table" {
  name       = "private-routes"
  network_id = yandex_vpc_network.main.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

#Security Groups
resource "yandex_vpc_security_group" "bastion_sg" {
  name        = "bastion-sg"
  network_id  = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [var.my_ip]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "web_sg" {
  name        = "web-sg"
  network_id  = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["10.0.0.0/16"]  # От балансировщика (внутренняя сеть)
  }

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["10.0.1.0/24"]  # SSH от bastion (публичная подсеть)
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "es_sg" {
  name        = "es-sg"
  network_id  = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    port           = 9200
    v4_cidr_blocks = ["10.0.0.0/16"]  # От Filebeat (веб), Kibana, Logstash
  }

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["10.0.1.0/24"]  # SSH от bastion
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "zabbix_server_sg" {
  name        = "zabbix-server-sg"
  network_id  = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    port           = 10051
    v4_cidr_blocks = ["10.0.0.0/16"]  # От агентов и Frontend
  }

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["10.0.1.0/24"]  # SSH от bastion
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "zabbix_frontend_sg" {
  name        = "zabbix-frontend-sg"
  network_id  = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]  # HTTP от мира
  }

  ingress {
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]  # HTTPS от мира
  }

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["10.0.1.0/24"]  # SSH от bastion
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "kibana_sg" {
  name        = "kibana-sg"
  network_id  = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    port           = 5601
    v4_cidr_blocks = ["0.0.0.0/0"]  # От мира
  }

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["10.0.1.0/24"]  # SSH от bastion
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

#Bastion
resource "yandex_compute_instance" "bastion" {
  name        = "bastion"
  hostname    = "bastion"
  zone        = "ru-central1-a"
  platform_id = "standard-v3"  # Intel Ice Lake

  resources {
    cores         = 2
    core_fraction = 20
    memory        = 2  # 2 GB
  }

  boot_disk {
    initialize_params {
      image_id = "fd8498pb5smsd5ch4gid"  # Ubuntu 22.04 LTS (актуальный ID на 16.10.2025)
      size     = 10
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true  # Публичный IP
    security_group_ids = [yandex_vpc_security_group.bastion_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }

  scheduling_policy {
    preemptible = true  # Прерываемая
  }
}
```
- `variables.tf`
```hcl
variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
  default     = "b1gi8b117513fp7ppsqs"
}

variable "folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
  default     = "b1gh19tdmqdb1m0tod0r"
}

variable "my_ip" {
  description = "Мой публичный IP"
  type        = string
  default     = "94.140.251.17/32"
}

variable "ssh_public_key_path" {
  description = "Путь к публичному ключу SSH"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}
```
- `outputs.tf`
```hcl
output "bastion_public_ip" {
  description = "Публичный IP bastion"
  value       = yandex_compute_instance.bastion.network_interface[0].nat_ip_address
}

output "vpc_id" {
  description = "VPC Network ID"
  value       = yandex_vpc_network.main.id
}
```