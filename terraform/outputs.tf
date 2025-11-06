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

output "alb_ip" {
  value       = yandex_alb_load_balancer.web.listener[0].endpoint[0].address[0].external_ipv4_address[0].address
  description = "Public IP of Application Load Balancer"
}

output "kibana_ip" {
  value       = yandex_compute_instance.kibana.network_interface.0.nat_ip_address
  description = "Public IP of Kibana VM"
}

output "zabbix_ip" {
  value       = yandex_compute_instance.zabbix.network_interface.0.nat_ip_address
  description = "Public IP Zabbix server"
}

output "zabbix_fqdn" {
  value       = "zabbix.ru-central1-a.internal"
  description = "FQDN Zabbix server"
}