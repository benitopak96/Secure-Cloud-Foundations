import subprocess
import os
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

# 1. Configuration
# Replace with the actual Vault URL from your Terraform output
VAULT_URL = "https://tyrant-secure-vault.vault.azure.net/" 

def get_vault_client():
    """Authenticates and returns the Key Vault client."""
    credential = DefaultAzureCredential()
    return SecretClient(vault_url=VAULT_URL, credential=credential)

def generate_wireguard_keys():
    """Generates a private and public key pair safely."""
    # List format prevents shell injection attacks
    private_key = subprocess.check_output(["wg", "genkey"]).decode("utf-8").strip()
    public_key = subprocess.check_output(["wg", "pubkey"], input=private_key.encode()).decode("utf-8").strip()
    return private_key, public_key

def store_secret(client_name, private_key):
    """Securely vaults the private key so it's never stored in plaintext."""
    try:
        client = get_vault_client()
        secret_name = f"{client_name}-vpn-key"
        client.set_secret(secret_name, private_key)
        print(f"🔐 Security: Private key for {client_name} vaulted successfully.")
    except Exception as e:
        print(f"❌ Vault Error: Could not store secret. {e}")

def create_client_config(client_name, private_key, client_ip, server_public_key, server_endpoint):
    """Creates a standardized .conf file for the client."""
    config_content = f"""[Interface]
PrivateKey = {private_key}
Address = {client_ip}/32
DNS = 1.1.1.1

[Peer]
PublicKey = {server_public_key}
Endpoint = {server_endpoint}:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
"""
    file_path = f"{client_name}_tyrantvpn.conf"
    with open(file_path, "w") as f:
        f.write(config_content)
    print(f"✅ Success: Configuration for {client_name} created at {file_path}")

if __name__ == "__main__":
    SVR_PUB_KEY = "YOUR_SERVER_PUBLIC_KEY_HERE"
    SVR_ENDPOINT = "YOUR_SERVER_IP_HERE"
    
    name = input("Enter Client Name: ").replace(" ", "-") # Sanitize name for Vault
    ip = "10.0.0.5" 
    
    # Execution
    priv, pub = generate_wireguard_keys()
    store_secret(name, priv) # This is the new security layer
    create_client_config(name, priv, ip, SVR_PUB_KEY, SVR_ENDPOINT)
    
    print(f"\nClient Public Key (Add this to your server config): {pub}")
