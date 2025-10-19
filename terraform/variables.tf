variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
  default     = "b1gi8b117513fp7ppsqs"
}

variable "folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
  default     = "b1gh19tdmqdb1m0tod0r"
}

variable "my_ip" {
  description = "Мой публичный IP"
  type        = string
  default     = "94.140.251.17/32"
}

variable "ssh_public_key_path" {
  description = "Путь к публичному ключу SSH"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}