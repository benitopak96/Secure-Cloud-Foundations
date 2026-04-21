package cloud_security

# Rule: Deny if a storage bucket does not have encryption enabled
deny[msg] {
    input.resource_type == "google_storage_bucket"
    not input.config.encryption
    msg = "ERROR: All storage buckets must have encryption enabled to protect sensitive data."
}
