# 1. Define the Google Cloud Provider
provider "google" {
  project = "your-project-id-here" # You'll replace this later
  region  = "us-central1"
}

# 2. Create a Custom VPC (Not the 'Default' one)
resource "google_compute_network" "secure_vpc" {
  name                    = "secure-production-vpc"
  auto_create_subnetworks = false # SECURITY: Prevents GCP from creating subnets in every region automatically
}

# 3. Create a Restricted Subnet (UPDATED WITH LOGGING)
resource "google_compute_subnetwork" "private_subnet" {
  name          = "private-security-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.secure_vpc.id
  
  private_ip_google_access = true 

  # ADD THIS BLOCK TO FIX CKV_GCP_26
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# 4. Create a "Deny All" Firewall Rule (Baseline Security)
resource "google_compute_firewall" "deny_all" {
  name    = "deny-all-ingress"
  network = google_compute_network.secure_vpc.name

  deny {
    protocol = "all"
  }

  priority    = 1000
  source_ranges = ["0.0.0.0/0"]
  description = "Baseline security: Deny all incoming traffic unless explicitly allowed"
}

# 5. Create a specific "Allow SSH" rule for YOUR IP only
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh-from-admin"
  network = google_compute_network.secure_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # SECURITY: Never use 0.0.0.0/0 for SSH. 
  # This demonstrates you understand Least Privilege.
  source_ranges = ["YOUR_OFFICE_IP/32"] 
  priority      = 900
}

# 6. Create a Hardened Storage Bucket
resource "google_storage_bucket" "security_logs" {
  name          = "tyrant-security-logs-001" # Must be globally unique
  location      = "US"
  force_destroy = true

  # SECURITY: Prevents accidental public exposure
  public_access_prevention = "enforced"

  # SECURITY: Ensures consistent IAM policies across all objects
  uniform_bucket_level_access = true

  # SECURITY: Enables object versioning (Protection against accidental deletion/ransomware)
  versioning {
    enabled = true
  }

  # SECURITY: Encryption using Google-managed keys
  encryption {
    default_kms_key_name = "" 
  }
}
