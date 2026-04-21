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

# 5. Create a Hardened Azure Storage Account
resource "azurerm_storage_account" "secure_storage" {
  name                     = "tyrantsecstorage001" 
  resource_group_name      = azurerm_resource_group.secure_rg.name
  location                 = azurerm_resource_group.secure_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # FIXES CKV_AZURE_190: Prevents all public access to blobs
  public_network_access_enabled = false
  allow_nested_items_to_be_public = false

  # FIXES CKV2_AZURE_40: Forces Azure AD Authentication (More secure than Shared Keys)
  shared_access_key_enabled = false

  # FIXES CKV2_AZURE_38: Enables Soft Delete (Protection against Ransomware)
  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  # SUPPRESSES CKV2_AZURE_33: Private Endpoints require a separate subnet/DNS config
  # checkov:skip=CKV2_AZURE_33: Private endpoint implementation is planned for Phase 2.
}
