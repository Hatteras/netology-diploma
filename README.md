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
```yaml
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