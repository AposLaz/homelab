locals {
  cloud_init_image = merge(var.k8s_cloud_image, {
    datastore_id = coalesce(
      var.k8s_cloud_image.datastore_id,
      var.proxmox_files_datastore_id
    )
  })


}

module "debian_image" {
  source = "./modules/proxmox-image"

  node_name = var.proxmox_node_name
  image     = local.cloud_init_image
}

module "debian_vm_template" {
  source = "./modules/proxmox-vm-template"

  node_name        = var.proxmox_node_name
  vm_template_name = var.vm_template_name
  vm_id            = var.template_vm_id
  tags             = var.tags

  # CPU and memory
  cpu    = var.template_cpu
  memory = var.template_memory

  # Storage
  image_id     = module.debian_image.image_id
  datastore_id = var.proxmox_vms_datastore_id
  disk_size    = var.template_disk_size

  # Network: existing bridge managed by Ansible
  bridge = var.bridge

  # Lifecycle
  stop_on_destroy = var.template_stop_on_destroy
}

##############################################################################
# Kubernetes cluster
##############################################################################

module "control_plane" {
  source = "./modules/proxmox-vm"

  for_each = {
    for index, node in var.k8s_nodes.control_plane :
    format("control-plane-%02d", index + 1) => node
  }

  vm_name   = each.key
  node_name = var.proxmox_node_name

  vm_template_id     = module.debian_vm_template.template_vm_id
  template_node_name = module.debian_vm_template.template_node_name
  datastore_id       = var.proxmox_vms_datastore_id

  private_cidr_addr = each.value.private_ip_cidr
  gateway_ip        = var.gateway_ip
  dns_servers       = var.dns_servers

  cpu       = each.value.cpu
  memory    = each.value.memory
  disk_size = each.value.storage_size

  ssh_username = var.ssh_username
  ssh_public_keys = [
    trimspace(file("${path.root}/${var.ssh_public_key_path}"))
  ]

  tags = setunion(var.tags, ["control-plane"])
}

module "workers" {
  source = "./modules/proxmox-vm"

  for_each = {
    for index, node in var.k8s_nodes.workers :
    format("worker-%02d", index + 1) => node
  }

  vm_name   = each.key
  node_name = var.proxmox_node_name

  vm_template_id     = module.debian_vm_template.template_vm_id
  template_node_name = module.debian_vm_template.template_node_name
  datastore_id       = var.proxmox_vms_datastore_id

  private_cidr_addr = each.value.private_ip_cidr
  gateway_ip        = var.gateway_ip
  dns_servers       = var.dns_servers

  cpu       = each.value.cpu
  memory    = each.value.memory
  disk_size = each.value.storage_size

  ssh_username = var.ssh_username
  ssh_public_keys = [
    trimspace(file("${path.root}/${var.ssh_public_key_path}"))
  ]

  tags = setunion(var.tags, ["worker"])
}
