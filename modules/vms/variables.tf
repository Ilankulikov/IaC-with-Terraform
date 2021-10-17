variable "vm_name" {
  type = string
  description = "The name of the virtual machine"
}

variable "rg_name" {
  type = string
  description = "The resource group name"
}

variable "location" {
  type = string
  description = "The location of resource group"
}

variable "username" {
  type = string
  description = "The username of the admin"
  default = "admin"
}

variable "subnet_id" {
  type = string
  description = "The subnet id"
}

variable "av_set_id" {
  type = string
  description = "The availability set id"
}

variable "password" {
  type = string
  description = " The password of the user"
}

variable "vm_image_id" {
  type = string
  description = "The id of the virtua machine image from shared gallery"
}

variable "vm_size" {
  type = string
  description = "The virtual machine size"
  default = "Standard_B1ls"
}