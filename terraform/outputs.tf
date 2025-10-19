output "bastion_public_ip" {
  description = "Публичный IP bastion"
  value       = yandex_compute_instance.bastion.network_interface[0].nat_ip_address
}

output "vpc_id" {
  description = "VPC Network ID"
  value       = yandex_vpc_network.main.id
}