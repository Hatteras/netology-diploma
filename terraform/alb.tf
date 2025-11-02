# Target Group
resource "yandex_alb_target_group" "web" {
  name = "web-target-group"

  target {
    subnet_id  = yandex_vpc_subnet.private_a.id
    ip_address = yandex_compute_instance.web["web1"].network_interface.0.ip_address
  }

  target {
    subnet_id  = yandex_vpc_subnet.private_b.id
    ip_address = yandex_compute_instance.web["web2"].network_interface.0.ip_address
  }

  depends_on = [yandex_vpc_security_group.web]
}

# Backend Group
resource "yandex_alb_backend_group" "web" {
  name = "web-backend-group"

  http_backend {
    name             = "web-backend"
    port             = 80
    target_group_ids = [yandex_alb_target_group.web.id]
    
    load_balancing_config {
      panic_threshold = 50
    }

    healthcheck {
      timeout             = "5s"
      interval            = "5s"
      healthy_threshold   = 2
      unhealthy_threshold = 2
      http_healthcheck {
        path = "/"
      }
    }
  }

  depends_on = [yandex_alb_target_group.web]
}

# HTTP Router
resource "yandex_alb_http_router" "web" {
  name = "web-router"
}

resource "yandex_alb_virtual_host" "web" {
  name           = "web-virtual-host"
  http_router_id = yandex_alb_http_router.web.id
  route {
    name = "root"
    http_route {
      http_match {
        path {
          prefix = "/"
        }
      }
      http_route_action {
        backend_group_id = yandex_alb_backend_group.web.id
        timeout          = "5s"
      }
    }
  }
}

# ALB
resource "yandex_alb_load_balancer" "web" {
  name       = "web-alb"
  network_id = yandex_vpc_network.diploma.id

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.public.id
    }
  }

  listener {
    name = "http-listener"
    endpoint {
      address {
        external_ipv4_address {}
      }
      ports = [80]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.web.id
      }
    }
  }

  security_group_ids = [yandex_vpc_security_group.alb.id]

  depends_on         = [null_resource.deploy_nginx, yandex_alb_virtual_host.web]
  }