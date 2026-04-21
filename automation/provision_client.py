import subprocess
import os

def generate_wireguard_keys():
    """Generates a private and public key pair for a new client."""
    private_key = subprocess.check_output(["wg", "genkey"]).decode("utf-8").strip()
    public_key = subprocess.check_output(["wg", "pubkey"], input=private_key.encode()).decode("utf-8").strip()
    return private_key, public_key

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
    # Example values - in Phase 2 these will be automated via API
    SVR_PUB_KEY = "YOUR_SERVER_PUBLIC_KEY_HERE"
    SVR_ENDPOINT = "YOUR_SERVER_IP_HERE"
    
    name = input("Enter Client Name: ")
    ip = "10.0.0.5" # This will be dynamic later
    
    priv, pub = generate_wireguard_keys()
    create_client_config(name, priv, ip, SVR_PUB_KEY, SVR_ENDPOINT)
    print(f"Client Public Key (Add this to your server!): {pub}")
