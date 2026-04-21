# 1. Define the Azure Provider
provider "azurerm" {
  features {}
}

# 2. Create a Resource Group
resource "azurerm_resource_group" "secure_rg" {
  name     = "tyrant-secure-resources"
  location = "East US"
}

# 3. Create a Secure Virtual Network (VNet)
resource "azurerm_virtual_network" "secure_vnet" {
  name                = "secure-production-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.secure_rg.location
  resource_group_name = azurerm_resource_group.secure_rg.name
}

# 4. Create a Network Security Group (NSG) - The "Firewall"
resource "azurerm_network_security_group" "secure_nsg" {
  name                = "production-nsg"
  location            = azurerm_resource_group.secure_rg.location
  resource_group_name = azurerm_resource_group.secure_rg.name

  # SECURITY: Explicitly deny all inbound traffic as a baseline
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# 5. Create a Secure Storage Account
resource "azurerm_storage_account" "secure_storage" {
  name                     = "tyrantsecstorage001" # Must be globally unique (lowercase/numbers only)
  resource_group_name      = azurerm_resource_group.secure_rg.name
  location                 = azurerm_resource_group.secure_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # SECURITY: Force HTTPS for all traffic
  enable_https_traffic_only = true
  
  # SECURITY: Minimum TLS version 1.2
  min_tls_version = "TLS1_2"

  # SECURITY: Disable public network access
  public_network_access_enabled = false
}
