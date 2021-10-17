output "private_ip"{
    value = azurerm_linux_virtual_machine.vm.private_ip_address
}

output "vm_id"{
    value = azurerm_linux_virtual_machine.vm.id
}

output "nic_id"{
    value = azurerm_network_interface.nic.id
}

output "ip_conf_name"{
    value = azurerm_network_interface.nic.ip_configuration[0]
}

output "vm_password"{
    value = azurerm_linux_virtual_machine.vm.admin_password
}