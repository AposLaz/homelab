locals {
  tags = sort(tolist(setunion(
    var.tags, ["vm_template", "managed-by-tofu"]
  )))
}

resource "proxmox_virtual_environment_vm" "vm_template" {
  name      = var.vm_template_name
  node_name = var.node_name
  vm_id     = var.vm_id

  tags = local.tags

  template        = true
  started         = false
  on_boot         = false
  stop_on_destroy = var.stop_on_destroy

  description   = "Reusable cloud-init VM template managed by OpenTofu"
  machine       = "q35"
  bios          = "ovmf"
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0"]

  operating_system {
    type = "l26"
  }

  # Raw cloud images may not include qemu-guest-agent. Enable it on clones
  # only when their initialization installs and starts the agent.
  agent {
    enabled = false
  }

  # Baseline capacity; the clone module explicitly sets its own resources.
  cpu {
    sockets = var.cpu.sockets
    cores   = var.cpu.cores
    type    = var.cpu.type
  }

  memory {
    dedicated = var.memory
    floating  = 0 # Disable ballooning for predictable node memory.
  }

  efi_disk {
    datastore_id = var.datastore_id
    type         = "4m"
    # Secure Boot keys; set to false for unsigned kernels.
    pre_enrolled_keys = true
  }

  disk {
    datastore_id = var.datastore_id
    import_from  = var.image_id
    interface    = "scsi0"
    cache        = "none"
    iothread     = true
    discard      = "on"
    size         = var.disk_size
  }

  initialization {
    datastore_id = var.datastore_id
    interface    = "ide2"

    # A generic default; clones supply their own address, user and SSH keys.
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  network_device {
    bridge = var.bridge
    model  = "virtio"
  }

  # Cloud images commonly send their console output to the first serial port.
  serial_device {}

  vga {
    type = "serial0"
  }
}
