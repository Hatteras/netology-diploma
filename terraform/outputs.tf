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