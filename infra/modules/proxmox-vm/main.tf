locals {
  tags = sort(tolist(setunion(
    var.tags, ["cloned_vm", "managed-by-tofu"]
  )))
}

resource "proxmox_virtual_environment_vm" "vm_clone" {
  name      = var.vm_name
  node_name = var.node_name

  tags            = local.tags
  started         = true
  on_boot         = true
  stop_on_destroy = true

  clone {
    vm_id        = var.vm_template_id
    node_name    = var.template_node_name
    full         = true
    datastore_id = var.datastore_id
  }

  agent {
    # Installed and started on the clone by cloud-config.tf.
    enabled = true
  }

  cpu {
    cores   = var.cpu.cores
    sockets = var.cpu.sockets
    type    = var.cpu.type
  }

  memory {
    dedicated = var.memory
    floating  = 0
  }

  disk {
    # Override the inherited boot disk. Its capacity can only grow.
    interface    = "scsi0"
    datastore_id = var.datastore_id
    size         = var.disk_size
    cache        = "none"
    iothread     = true
    discard      = "on"
  }

  initialization {
    datastore_id = var.datastore_id
    interface    = "ide2"

    dns {
      servers = var.dns_servers
    }
    ip_config {
      ipv4 {
        address = var.private_cidr_addr
        gateway = var.gateway_ip
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.user_data_cloud_config.id
  }
}
