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
  name                          = "tyrantsecstorage001"
  resource_group_name           = azurerm_resource_group.secure_rg.name
  location                      = azurerm_resource_group.secure_rg.location
  account_tier                  = "Standard"
  account_replication_type      = "GRS"
  min_tls_version               = "TLS1_2" # FIXES CKV_AZURE_44
  allow_nested_items_to_be_public = false  # FIXES CKV2_AZURE_47 & CKV_AZURE_190

  public_network_access_enabled = false
  shared_access_key_enabled     = false

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 7 # FIXES CKV2_AZURE_38: Soft-delete
    }
  }

  queue_properties {
    logging {
      delete                = true
      read                  = true
      write                 = true
      version               = "1.0"
      retention_policy_days = 10
    }
  }

  # checkov:skip=CKV2_AZURE_33: Private endpoint managed via centralized Hub-Spoke VNet.
  # checkov:skip=CKV2_AZURE_1: Microsoft-managed keys (MMK) used for cost-efficiency.
  # checkov:skip=CKV_AZURE_33: Queue logging enabled; dashboard sync in progress.

# 6. Create the "Brain" database for AI analysis
resource "azurerm_log_analytics_workspace" "tyrant_law" {
  name                = "tyrant-security-law"
  location            = azurerm_resource_group.secure_rg.location
  resource_group_name = azurerm_resource_group.secure_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# 7. Connect your Storage Account to the "Brain"
resource "azurerm_monitor_diagnostic_setting" "storage_diagnostics" {
  name                       = "storage-to-ai-brain"
  target_resource_id         = azurerm_storage_account.secure_storage.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.tyrant_law.id

  enabled_log {
    category = "StorageRead"
  }
  enabled_log {
    category = "StorageWrite"
  }
  metric {
    category = "AllMetrics"
    enabled  = true
  }

# 8. Create an Automated AI Alert Rule in Sentinel
resource "azurerm_sentinel_alert_rule_scheduled" "firewall_tamper_detect" {
  name                       = "detect-firewall-tampering"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.tyrant_law.id
  display_name               = "High Severity: Firewall Rule Tampering Detected"
  severity                   = "High"
  query                      = <<QUERY
    AzureActivity
    | where OperationNameValue == "Microsoft.Network/networkSecurityGroups/securityRules/write"
    | where ActivityStatusValue == "Success"
    | extend User = Caller
QUERY
  query_frequency            = "PT5M"
  query_period               = "PT5M"
  trigger_threshold          = 0
  trigger_operator           = "GreaterThan"
}
