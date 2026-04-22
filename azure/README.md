# TyrantNetworks Azure Security Infrastructure

## Overview
This Terraform configuration deploys the Azure security monitoring stack for TyrantNetworks VPN infrastructure.

## Architecture
## Resources Deployed
- Resource Group: `tyrant-eye` (Canada Central)
- Log Analytics Workspace: `tyrant-sentinel-logs`
- Microsoft Sentinel SIEM
- Sentinel Alert Rule: WireGuard VPN session detection
- Logic App: `TyrantVPN-Alert-Playbook`
- Data Collection Rule: Syslog ingestion from VPS

## Prerequisites
- Azure CLI authenticated
- Terraform >= 1.0
- VPS registered in Azure Arc
- Azure Monitor Agent installed on VPS

## Usage
```bash
cd azure/
terraform init
terraform plan
terraform apply
```
