# NAT-шлюз (управляется Yandex'ом)
resource "yandex_vpc_gateway" "nat_gateway" {
  name = "nat-gateway"
  shared_egress_gateway {}
}

# Маршрутная таблица
resource "yandex_vpc_route_table" "nat" {
  name       = "private-rt"
  network_id = yandex_vpc_network.diploma.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}