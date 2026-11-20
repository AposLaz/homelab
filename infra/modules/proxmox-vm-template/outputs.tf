output "template_vm_id" {
  description = "Template VM ID to use when cloning"
  value       = proxmox_virtual_environment_vm.vm_template.vm_id
}

output "template_node_name" {
  description = "Proxmox node hosting the template"
  value       = proxmox_virtual_environment_vm.vm_template.node_name
}

output "template_name" {
  description = "Name of the reusable VM template"
  value       = proxmox_virtual_environment_vm.vm_template.name
}
