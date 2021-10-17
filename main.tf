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
  name     = "week_05_project_Bonus"
  location = var.location
}

# Create a virtual network

resource "azurerm_virtual_network" "vnet" {
  name                = "Weight-Tracker-vnet"
  address_space       = ["16.0.0.0/20"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create a subnet for the application

resource "azurerm_subnet" "subnet" {
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_prefix]
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
  name                = "app-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Associate the subnets to a network security group

resource "azurerm_subnet_network_security_group_association" "subnet_association" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
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
  network_security_group_name = azurerm_network_security_group.nsg.name
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
  subnet_id   = azurerm_subnet.subnet.id 
  password    = var.password
  vm_image_id = var.app_vm_image_id
  av_set_id   = azurerm_availability_set.as.id
  location    = azurerm_resource_group.rg.location
  username    = var.username
  vm_size     = var.app_vm_size
}

# Create managed postgresql database

resource "azurerm_postgresql_server" "postgresql" {
  name                = "wt-psqlserver"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  administrator_login          = var.pg_user
  administrator_login_password = var.pg_password

  sku_name   = "B_Gen5_1"
  version    = "11"
  storage_mb = 5120

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = false

  public_network_access_enabled = true
  ssl_enforcement_enabled       = false
}

# Create new database

resource "azurerm_postgresql_database" "wt_db" {
  name                = var.pg_database
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_postgresql_server.postgresql.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

# Create firewall rule so only the application servers can access to the database

resource "azurerm_postgresql_firewall_rule" "firewall_rule" {
  name                = "app"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_postgresql_server.postgresql.name
  start_ip_address    = azurerm_public_ip.ip.ip_address
  end_ip_address      = azurerm_public_ip.ip.ip_address
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
        "commandToExecute": "/home/ilan/setenv.sh ${azurerm_public_ip.ip.ip_address} ${azurerm_postgresql_server.postgresql.name}.postgres.database.azure.com ${var.pg_user}@${azurerm_postgresql_server.postgresql.name} ${azurerm_postgresql_database.wt_db.name} ${var.pg_password}"
    }
  SETTINGS

  tags = {
    environment = "Development"
  }

  depends_on = [
    azurerm_postgresql_database.wt_db,
    azurerm_postgresql_firewall_rule.firewall_rule,
    azurerm_postgresql_server.postgresql

  ]
}
