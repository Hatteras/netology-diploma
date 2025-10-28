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