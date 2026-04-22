# =============================================================
# TyrantNetworks - Azure Security Infrastructure
# Secure-Cloud-Foundations | azure/main.tf
# =============================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# -------------------------------------------------------------
# 1. Resource Group - "tyrant-eye"
# -------------------------------------------------------------
resource "azurerm_resource_group" "tyrant_eye" {
  name     = "tyrant-eye"
  location = "Canada Central"
}

# -------------------------------------------------------------
# 2. Log Analytics Workspace - "Tyrant-Sentinel-Logs"
# Collects WireGuard VPN logs from TyrantNetworks-Canada VPS
# -------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "sentinel_logs" {
  name                = "tyrant-sentinel-logs"
  location            = azurerm_resource_group.tyrant_eye.location
  resource_group_name = azurerm_resource_group.tyrant_eye.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# -------------------------------------------------------------
# 3. Microsoft Sentinel
# SIEM layer on top of Log Analytics
# -------------------------------------------------------------
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "sentinel" {
  workspace_id = azurerm_log_analytics_workspace.sentinel_logs.id
}

# -------------------------------------------------------------
# 4. Sentinel Alert Rule - New VPN Session Detection
# Triggers when wg-easy Docker logs a new peer session
# -------------------------------------------------------------
resource "azurerm_sentinel_alert_rule_scheduled" "vpn_session_detected" {
  name                       = "new-vpn-session-detected"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel_logs.id
  display_name               = "New VPN Session Detected"
  severity                   = "Medium"
  enabled                    = true

  query = <<QUERY
Syslog
| where ProcessName == "wireguard"
| where SyslogMessage contains "New Session"
| project TimeGenerated, Computer, SyslogMessage
QUERY

  query_frequency = "PT5M"
  query_period    = "PT5M"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0
}

# -------------------------------------------------------------
# 5. Logic App - TyrantVPN Alert Playbook
# Sends email via SMTP when VPN incident is created
# -------------------------------------------------------------
resource "azurerm_logic_app_workflow" "vpn_alert_playbook" {
  name                = "TyrantVPN-Alert-Playbook"
  location            = azurerm_resource_group.tyrant_eye.location
  resource_group_name = azurerm_resource_group.tyrant_eye.name

  identity {
    type = "SystemAssigned"
  }

  tags = {
    purpose = "VPN session email alerting"
    sender  = "noreply@tyrantnetworks.com"
  }
}

# -------------------------------------------------------------
# 6. Sentinel Automation Rule
# Links the VPN alert to the Logic App playbook
# -------------------------------------------------------------
resource "azurerm_sentinel_automation_rule" "vpn_alert_automation" {
  name                       = "vpn-session-email-alert"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel_logs.id
  display_name               = "VPN Session Email Alert"
  order                      = 1
  enabled                    = true

  condition {
    operator = "Contains"
    property = "IncidentTitle"
    values   = ["New VPN Session Detected"]
  }

  action_incident {
    order  = 1
    status = "Active"
  }
}

# -------------------------------------------------------------
# 7. Data Collection Rule - TyrantVPN-Logs-DCR
# Routes syslog from VPS Azure Arc machine to Log Analytics
# -------------------------------------------------------------
resource "azurerm_monitor_data_collection_rule" "vpn_logs" {
  name                = "TyrantVPN-Logs-DCR"
  resource_group_name = azurerm_resource_group.tyrant_eye.name
  location            = azurerm_resource_group.tyrant_eye.location

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.sentinel_logs.id
      name                  = "tyrant-sentinel-logs"
    }
  }

  data_flow {
    streams      = ["Microsoft-Syslog"]
    destinations = ["tyrant-sentinel-logs"]
  }

  data_sources {
    syslog {
      facility_names = ["local0"]
      log_levels     = ["Info", "Warning", "Error"]
      name           = "wireguard-syslog"
      streams        = ["Microsoft-Syslog"]
    }
  }
}

# -------------------------------------------------------------
# Outputs
# -------------------------------------------------------------
output "resource_group" {
  value = azurerm_resource_group.tyrant_eye.name
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.sentinel_logs.id
}

output "logic_app_name" {
  value = azurerm_logic_app_workflow.vpn_alert_playbook.name
}
