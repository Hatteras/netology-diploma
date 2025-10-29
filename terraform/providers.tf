provider "yandex" {
  service_account_key_file = pathexpand("~/.yc/key.json") # Авторизованный ключ
  cloud_id                 = var.yc_cloud_id
  folder_id                = var.yc_folder_id
  zone                     = "ru-central1-a"
}