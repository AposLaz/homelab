output "vm_id" {
  description = "ID of the cloned VM"
  value       = proxmox_virtual_environment_vm.vm_clone.vm_id
}

output "vm_ipv4_addresses" {
  description = "Guest-agent IPv4 addresses excluding loopback and link-local addresses"
  value = flatten([
    for addresses in proxmox_virtual_environment_vm.vm_clone.ipv4_addresses : [
      for address in addresses : address
      if !startswith(address, "127.") && !startswith(address, "169.254.")
    ]
  ])
}

output "vm_ipv4_address" {
  description = "First non-loopback, non-link-local IPv4 address, or null when unavailable"
  value = try(flatten([
    for addresses in proxmox_virtual_environment_vm.vm_clone.ipv4_addresses : [
      for address in addresses : address
      if !startswith(address, "127.") && !startswith(address, "169.254.")
    ]
  ])[0], null)
}
