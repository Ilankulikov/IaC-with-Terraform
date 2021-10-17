# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
}

# Create a resource group

resource "azurerm_resource_group" "rg" {
  name     = "week_05_project"
  location = var.location
}

# Create a virtual network

resource "azurerm_virtual_network" "vnet" {
  name                = "Weight-Tracker-vnet"
  address_space       = ["16.0.0.0/20"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create a subnet for the application and DB

resource "azurerm_subnet" "subnet" {
  count                = length(var.env_prefix)
  name                 = "${var.env_prefix[count.index]}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_prefix[count.index]]
}

# Create a public static IP

resource "azurerm_public_ip" "ip" {
  name                = "lb-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# Create a network security group for both app and db

resource "azurerm_network_security_group" "nsg" {
  count               = length(var.env_prefix)
  name                = "${var.env_prefix[count.index]}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Associate the subnets to a network security group

resource "azurerm_subnet_network_security_group_association" "subnet_association" {
  count                     = length(azurerm_subnet.subnet)
  subnet_id                 = azurerm_subnet.subnet[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg[count.index].id
  depends_on                = [module.application_vms]
}

# Create an inbound rule for app nsg

resource "azurerm_network_security_rule" "app_nsg_rule" {
  name                        = "port8080"
  priority                    = 100
  direction                   = "inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = 8080
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg[0].name //0 is the index of the app nsg
}

# Create an inbound rule for db nsg

resource "azurerm_network_security_rule" "db_nsg_rule" {
  name                        = "port5432"
  priority                    = 100
  direction                   = "inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = 5432
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg[1].name //1 is the index of the db nsg
}

# Create a load balancer for the VM's that running the application

resource "azurerm_lb" "lb" {
  name                = "App-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  frontend_ip_configuration {
    name                 = "LoadBalancerFrontEnd"
    public_ip_address_id = azurerm_public_ip.ip.id
  }
}

# Create a health probe for load balancer

resource "azurerm_lb_probe" "lb_probe" {
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "app-health-probe"
  port                = 8080
}

# Create a load balancer rule

resource "azurerm_lb_rule" "tcp" {
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "app-lb-rule"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 8080
  probe_id                       = azurerm_lb_probe.lb_probe.id
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.bp.id
  disable_outbound_snat          = true
}

# Create a backend pool for load balancer

resource "azurerm_lb_backend_address_pool" "bp" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "app-pool"
}

# Associate network interface (app virtual machine) with the load balancer backend pool.

resource "azurerm_network_interface_backend_address_pool_association" "nic_backend_association" {
  count                   = length(module.application_vms)
  network_interface_id    = module.application_vms[count.index].nic_id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bp.id
}

# Create an availability set for VM's runnings the application

resource "azurerm_availability_set" "as" {
  name                = "Web-app-as"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    environment = "Development"
  }
}

# Create 2 virtual machines for the application

module "application_vms" {
  source      = "./modules/vms"
  count       = 2
  rg_name     = azurerm_resource_group.rg.name
  vm_name     = "app-vm${count.index + 1}"
  subnet_id   = azurerm_subnet.subnet[0].id #0 is the index of the first subnet which was created for the app vms.
  password    = var.password
  vm_image_id = var.app_vm_image_id
  av_set_id   = azurerm_availability_set.as.id
  location    = azurerm_resource_group.rg.location
  username    = var.username
  vm_size     = var.app_vm_size
}

# Create virtual machine for the database

module "db_vm" {
  source      = "./modules/vms"
  rg_name     = azurerm_resource_group.rg.name
  vm_name     = "db-vm"
  subnet_id   = azurerm_subnet.subnet[1].id #1 is the index of the 2nd subnet which was created for the db vm.
  password    = var.password
  av_set_id   = null
  vm_image_id = var.db_vm_image_id
  location    = azurerm_resource_group.rg.location
  username    = var.username
  vm_size     = var.db_vm_size
}

# This extention runs script that stored in the vm image to set the .env in the app folder.

resource "azurerm_virtual_machine_extension" "app_vm_extension" {
  count                = length(module.application_vms)
  name                 = "app_ex${count.index + 1}"
  virtual_machine_id   = module.application_vms[count.index].vm_id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": "/home/ilan/setenv.sh ${azurerm_public_ip.ip.ip_address} ${module.db_vm.private_ip} ${var.pg_user} ${var.pg_database} ${var.pg_password}"
    }
SETTINGS


  tags = {
    environment = "Development"
  }
}
