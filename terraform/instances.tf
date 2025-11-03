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
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}\nubuntu:${file("~/.ssh/emis_id_ed25519.pub")}}"
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
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}\nubuntu:${file("~/.ssh/emis_id_ed25519.pub")}}"
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
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}\nubuntu:${file("~/.ssh/emis_id_ed25519.pub")}}"
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
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}\nubuntu:${file("~/.ssh/emis_id_ed25519.pub")}}"
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
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}\nubuntu:${file("~/.ssh/emis_id_ed25519.pub")}}"
  }

  scheduling_policy {
    preemptible = true
  }

  allow_stopping_for_update = true
}