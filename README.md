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
   - Создан файл ~/.yc/credentials.json для хранения ключей Yandex Cloud вида:
  ```json
  {
  "service_account_id": "<service-account-id>",
  "key_id": "<key-id>",
  "private_key": "<private-key>"
  }
  ```
  Здесь <key-id> и <private-key> - соответственно ID и значение статического ключа доступа.
  Файл защищён и добавлен в .gitignore:
  ```bash
  chmod 600 ~/.yc/credentials.json
  echo "~/.yc/credentials.json" >> .gitignore
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
6. **Проведено первичное тестирование**
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