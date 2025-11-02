resource "null_resource" "deploy_nginx" {
  triggers = {
    web1_id = yandex_compute_instance.web["web1"].id
    web2_id = yandex_compute_instance.web["web2"].id
  }

  provisioner "local-exec" {
    command     = <<-EOT
      # Обновляем SSH и inventory
      ./bastion-config.sh
      ./update-inventory.sh

      # Ожидаем "поднятия" Nginx
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