resource "null_resource" "deploy_nginx" {
  triggers = {
    web1_id = yandex_compute_instance.web["web1"].id
    web2_id = yandex_compute_instance.web["web2"].id
  }

  provisioner "local-exec" {
    command     = <<-EOT
      # Обновляем SSH и inventory
      ~/netology-diploma/terraform/bastion-config.sh
      ~/netology-diploma/terraform/update-inventory.sh

      # Ожидаем "поднятия" web-серверов
      sleep 30

      # Запускаем Ansible
      cd ${path.module}/../ansible
      ansible-playbook -i inventory.ini --inventory hosts.yml playbooks/web-servers.yml
    EOT
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [
    yandex_compute_instance.web,
    yandex_compute_instance.bastion
  ]
}

# Zabbix Server deployment
resource "null_resource" "deploy_zabbix_server" {
  triggers = {
    zabbix_id = yandex_compute_instance.zabbix.id
  }

  provisioner "local-exec" {
    command     = <<-EOT
      # Обновляем SSH и inventory (на всякий случай)
      ~/netology-diploma/terraform/update-inventory.sh
      ~/netology-diploma/terraform/bastion-config.sh

      # Ожидаем "поднятия" ВМ Zabbix Server
      sleep 30

      # Проверяем доступность
      ssh -o ConnectTimeout=10 zabbix exit || exit 1

      # Запускаем Ansible
      cd ${path.module}/../ansible
      ansible-playbook -i inventory.ini --inventory hosts.yml playbooks/zabbix-server.yml
    EOT
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [
    yandex_compute_instance.zabbix,
    yandex_vpc_security_group.zabbix
  ]
}

resource "null_resource" "deploy_zabbix_agent" {
  triggers = {
    web1_id          = yandex_compute_instance.web["web1"].id
    web2_id          = yandex_compute_instance.web["web2"].id
    elasticsearch_id = yandex_compute_instance.elasticsearch.id
    kibana_id        = yandex_compute_instance.kibana.id
    bastion_id       = yandex_compute_instance.bastion.id
    zabbix_id        = yandex_compute_instance.zabbix.id
  }

  provisioner "local-exec" {
    command     = <<-EOT
      # Обновляем SSH и inventory (на всякий случай)
      ~/netology-diploma/terraform/update-inventory.sh
      ~/netology-diploma/terraform/bastion-config.sh

      # Ожидаем "поднятия" всех ВМ
      sleep 30

      # Запускаем Ansible
      cd ${path.module}/../ansible
      ansible-playbook -i inventory.ini --inventory hosts.yml playbooks/zabbix-agent.yml
    EOT
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [
    null_resource.deploy_zabbix_server,
    yandex_compute_instance.web,
    yandex_compute_instance.elasticsearch,
    yandex_compute_instance.kibana,
    yandex_compute_instance.bastion
  ]
}