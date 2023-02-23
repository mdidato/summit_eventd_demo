output "resource_group_name" {
  value = var.resource_group_name
}

output "server_ips" {
  value = azurerm_linux_virtual_machine.my_terraform_vm[*].public_ip_address
}

output "appgw_fe_ip" {
  value = azurerm_public_ip.my_terraform_public_ip_appgw.ip_address
}

#output "tls_private_key" {
#  value     = tls_private_key.example_ssh.private_key_pem
#  sensitive = true
#}
