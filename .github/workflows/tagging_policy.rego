package main

# Rule: Every resource must have an 'Environment' tag
deny[msg] {
    resource := input.resource_changes[_]
    tags := resource.change.after.tags
    not tags.Environment
    msg = sprintf("Resource %v is missing the required 'Environment' tag", [resource.address])
}
