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

# 6. Create a separate bucket for LOGS (The Vault)
resource "google_storage_bucket" "logging_bucket" {
  name                        = "tyrant-infra-logs-vault"
  location                    = "US"
  public_access_prevention    = "enforced" # FIXES CKV_GCP_114
  uniform_bucket_level_access = true

  versioning {
    enabled = true # FIXES CKV_GCP_78
  }

  # checkov:skip=CKV_GCP_62: This is the root logging bucket; recursive logging is not required.
}

# 7. Create your Secure Data Bucket
resource "google_storage_bucket" "secure_bucket" {
  name                        = "tyrant-secure-storage-001"
  location                    = "US"
  force_destroy               = true
  public_access_prevention    = "enforced" # FIXES CKV_GCP_114
  uniform_bucket_level_access = true

  versioning {
    enabled = true # FIXES CKV_GCP_78
  }

  logging {
    log_bucket        = google_storage_bucket.logging_bucket.name
    log_object_prefix = "gcs-access-logs/"
  }
}
