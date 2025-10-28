variable "yc_cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
  default     = null
}

variable "yc_folder_id" {
  description = "Yandex Folder ID"
  type        = string
  default     = null
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "diploma-vpc"
}

variable "my_ip" {
  description = "My public IP for SSH access"
  type        = string
  sensitive   = true
}

variable "public_subnet_cidr" {
  description = "CIDR for public subnet"
  type        = string
  default     = "192.168.1.0/24"
}

variable "private_subnet_a_cidr" {
  description = "CIDR for private subnet in zone a"
  type        = string
  default     = "192.168.2.0/24"
}

variable "private_subnet_b_cidr" {
  description = "CIDR for private subnet in zone b"
  type        = string
  default     = "192.168.3.0/24"
}