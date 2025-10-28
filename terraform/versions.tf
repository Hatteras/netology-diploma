terraform {
  required_version = ">= 1.13.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.168.0"
    }
  }
}