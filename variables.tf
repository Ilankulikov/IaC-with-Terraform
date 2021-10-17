variable "location" {
  type    = string
  default = "eastus"
}

variable "subnet_prefix" {
  default = "16.0.1.0/24"
}

variable "env_prefix" {
  default = [
    "app",
    "db"
  ]
}

variable "username" {
  type        = string
  description = "User name"
}

variable "password" {
  type        = string
  description = "User password"
}

variable "app_vm_image_id" {
  type        = string
  description = "The image resource id of the app vm"
}

variable "vm_name" {
  type        = string
  description = "Name of virtual machine"
}

variable "app_vm_size" {
  type        = string
  description = "The virtual machine size"
  default     = "Standard_B1ls"
}

variable "pg_user" {
  type        = string
  description = "Postgresql database user name"
  default     = "postgres"
}
variable "pg_database" {
  type        = string
  description = "Postgresql database name"
  default     = "postgres"
}

variable "pg_password" {
  type        = string
  description = "Database password"
}
