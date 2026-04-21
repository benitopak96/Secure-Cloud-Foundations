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

# 3. Create a Restricted Subnet
resource "google_compute_subnetwork" "private_subnet" {
  name          = "private-security-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.secure_vpc.id
  
  # SECURITY: Ensures instances don't need public IPs to talk to Google Services
  private_ip_google_access = true 
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
