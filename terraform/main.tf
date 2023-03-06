# Create virtual network
resource "azurerm_virtual_network" "my_terraform_network" {
  name                = "summitVnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
}

# Create subnet
resource "azurerm_subnet" "my_terraform_subnet" {
  name                 = "summitSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "my_terraform_aapgw_subnet" {
  name                 = "summitAppGWSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "my_terraform_public_ip" {
  count               = length(var.servername)
  name                = "${var.servername[count.index]}_pubip"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  allocation_method   = "Dynamic"
}

resource "azurerm_public_ip" "my_terraform_public_ip_appgw" {
  name                = "summit_appgw_pubip"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "my_terraform_public_ip_aap" {
  count               = length(var.aapservername)
  name                = "${var.aapservername[count.index]}_pubip"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  allocation_method   = "Dynamic"
}

resource "azurerm_public_ip" "my_terraform_public_ip_monitoring" {
  count               = length(var.monitoringservername)
  name                = "${var.monitoringservername[count.index]}_pubip"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "my_terraform_nsg" {
  name                = "SummitNSG"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "HTTP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "HTTPS"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface for web servers
resource "azurerm_network_interface" "my_terraform_nic" {
  count               = length(var.servername)
  name                = "${var.servername[count.index]}_nic"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "${var.servername[count.index]}_nic_config"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_terraform_public_ip[count.index].id
  }
}

# create network interface for AAP servers
resource "azurerm_network_interface" "my_terraform_nic_aap" {
  count               = length(var.aapservername)
  name                = "${var.aapservername[count.index]}_nic"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "${var.aapservername[count.index]}_nic_config"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_terraform_public_ip_aap[count.index].id
  }
}

# create network interface for monitoring servers
resource "azurerm_network_interface" "my_terraform_nic_monitoring" {
  count               = length(var.monitoringservername)
  name                = "${var.monitoringservername[count.index]}_nic"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "${var.monitoringservername[count.index]}_nic_config"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_terraform_public_ip_monitoring[count.index].id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "WebnsgConnect" {
  count               = length(var.servername)
  network_interface_id      = azurerm_network_interface.my_terraform_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
}

resource "azurerm_network_interface_security_group_association" "AAPnsgConnect" {
  count               = length(var.aapservername)
  network_interface_id      = azurerm_network_interface.my_terraform_nic_aap[count.index].id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
}

resource "azurerm_network_interface_security_group_association" "monitornsgConnect" {
  count               = length(var.monitoringservername)
  network_interface_id      = azurerm_network_interface.my_terraform_nic_monitoring[count.index].id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = var.resource_group_name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "my_storage_account" {
  name                     = "diag${random_id.random_id.hex}"
  location                 = var.resource_group_location
  resource_group_name      = var.resource_group_name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


# Create virtual machine web servers
resource "azurerm_linux_virtual_machine" "my_terraform_vm" {
  count                 = length(var.servername)
  name                  = var.servername[count.index]
  location              = var.resource_group_location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.my_terraform_nic[count.index].id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "${var.servername[count.index]}_OSdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "9_0"
    version   = "latest"
  }

  computer_name                   = var.servername[count.index]
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDPZA3N3U15rqQVtgUBH9inE6YW/ubCGJ8dkVqmMp8pTCTMG9wNmIlx0/hzu8gmAAR4PM6DBtjQMVgAukNoUNAOM9UAgEILWcWXbP7OfVQGit03GAsn2u+M6yJd1rXMeSDEYOYRocabt5vWdNhJNkbyitgNTA6SklqmDbQe/7cMVWzZCwEmW3vS5i2laNOEYOVXDjv2q0RDDlW/orufquRJntXuLY7LqSkiv0V+aVtXciXgj1IZh33sZ/hqQl7QqDI/tX4Xi6LFq6gipjrJHYIjzoi/dEO8zAHsQQVfHoeM/Qt9lcDDz5Oe2XJFhRFosplXvDO6/2imodG1vOW9ZRvxbqiix6+yxflgo9vhZ9GIgPiHXKoiCQtl9qXnPS/wZcDAFJkvEPFSMvGCpivbzJjeCCaSN9Igefvq2DMuxCmUCMR+U1JznwOr+bgWS23iZ63x1WcR80Sf6EW93bIWxa8cqkrO3pNHBR4/KcAWcwlb2iSgfxviZhhjYIr6asOYFK9vtaStgI7jzs0Y35g9Tp2XrgkFt8feVMfcpZ9q5qi647romYESeThY/yLtyoGaDTjICFotOKwRH0G4i9JFTAJm3CjEaXMp4WLaK94tuM+BQJrzevXjLBKZX2cDh2PE6fB26Fp3BTKFjdH3c27CvTNRC1w0W425pS+RPdjRESYNwQ== mdidato@mdidato-mac"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }
}

# Create virtual machine AAP servers
resource "azurerm_linux_virtual_machine" "my_terraform_vm_aap" {
  count                 = length(var.aapservername)
  name                  = var.aapservername[count.index]
  location              = var.resource_group_location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.my_terraform_nic_aap[count.index].id]
  size                  = "Standard_B4ms"

  os_disk {
    name                 = "${var.aapservername[count.index]}_OSdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "9_0"
    version   = "latest"
  }

  computer_name                   = var.aapservername[count.index]
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDPZA3N3U15rqQVtgUBH9inE6YW/ubCGJ8dkVqmMp8pTCTMG9wNmIlx0/hzu8gmAAR4PM6DBtjQMVgAukNoUNAOM9UAgEILWcWXbP7OfVQGit03GAsn2u+M6yJd1rXMeSDEYOYRocabt5vWdNhJNkbyitgNTA6SklqmDbQe/7cMVWzZCwEmW3vS5i2laNOEYOVXDjv2q0RDDlW/orufquRJntXuLY7LqSkiv0V+aVtXciXgj1IZh33sZ/hqQl7QqDI/tX4Xi6LFq6gipjrJHYIjzoi/dEO8zAHsQQVfHoeM/Qt9lcDDz5Oe2XJFhRFosplXvDO6/2imodG1vOW9ZRvxbqiix6+yxflgo9vhZ9GIgPiHXKoiCQtl9qXnPS/wZcDAFJkvEPFSMvGCpivbzJjeCCaSN9Igefvq2DMuxCmUCMR+U1JznwOr+bgWS23iZ63x1WcR80Sf6EW93bIWxa8cqkrO3pNHBR4/KcAWcwlb2iSgfxviZhhjYIr6asOYFK9vtaStgI7jzs0Y35g9Tp2XrgkFt8feVMfcpZ9q5qi647romYESeThY/yLtyoGaDTjICFotOKwRH0G4i9JFTAJm3CjEaXMp4WLaK94tuM+BQJrzevXjLBKZX2cDh2PE6fB26Fp3BTKFjdH3c27CvTNRC1w0W425pS+RPdjRESYNwQ== mdidato@mdidato-mac"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }
}

# Create virtual machine monitoring servers
resource "azurerm_linux_virtual_machine" "my_terraform_vm_monitoring" {
  count                 = length(var.monitoringservername)
  name                  = var.monitoringservername[count.index]
  location              = var.resource_group_location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.my_terraform_nic_monitoring[count.index].id]
  size                  = "Standard_B4ms"

  os_disk {
    name                 = "${var.monitoringservername[count.index]}_OSdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "8.6"
    version   = "latest"
  }

  computer_name                   = var.monitoringservername[count.index]
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDPZA3N3U15rqQVtgUBH9inE6YW/ubCGJ8dkVqmMp8pTCTMG9wNmIlx0/hzu8gmAAR4PM6DBtjQMVgAukNoUNAOM9UAgEILWcWXbP7OfVQGit03GAsn2u+M6yJd1rXMeSDEYOYRocabt5vWdNhJNkbyitgNTA6SklqmDbQe/7cMVWzZCwEmW3vS5i2laNOEYOVXDjv2q0RDDlW/orufquRJntXuLY7LqSkiv0V+aVtXciXgj1IZh33sZ/hqQl7QqDI/tX4Xi6LFq6gipjrJHYIjzoi/dEO8zAHsQQVfHoeM/Qt9lcDDz5Oe2XJFhRFosplXvDO6/2imodG1vOW9ZRvxbqiix6+yxflgo9vhZ9GIgPiHXKoiCQtl9qXnPS/wZcDAFJkvEPFSMvGCpivbzJjeCCaSN9Igefvq2DMuxCmUCMR+U1JznwOr+bgWS23iZ63x1WcR80Sf6EW93bIWxa8cqkrO3pNHBR4/KcAWcwlb2iSgfxviZhhjYIr6asOYFK9vtaStgI7jzs0Y35g9Tp2XrgkFt8feVMfcpZ9q5qi647romYESeThY/yLtyoGaDTjICFotOKwRH0G4i9JFTAJm3CjEaXMp4WLaK94tuM+BQJrzevXjLBKZX2cDh2PE6fB26Fp3BTKFjdH3c27CvTNRC1w0W425pS+RPdjRESYNwQ== mdidato@mdidato-mac"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }
}

# since these variables are re-used - a locals block makes this more maintainable
locals {
  backend_address_pool_name      = "${azurerm_virtual_network.my_terraform_network.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.my_terraform_network.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.my_terraform_network.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.my_terraform_network.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.my_terraform_network.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.my_terraform_network.name}-rqrt"
}

resource "azurerm_application_gateway" "network" {
  name                  = "summit_appgateway"
  location              = var.resource_group_location
  resource_group_name   = var.resource_group_name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "summit_appgw_fe_ip_configuration"
    subnet_id = azurerm_subnet.my_terraform_aapgw_subnet.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.my_terraform_public_ip_appgw.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    priority                   = 25
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "app_gw_be_add" {
  count                   = length(var.servername)
  network_interface_id    = azurerm_network_interface.my_terraform_nic[count.index].id
  ip_configuration_name   = "${var.servername[count.index]}_nic_config"
  backend_address_pool_id = tolist(azurerm_application_gateway.network.backend_address_pool).0.id
}

