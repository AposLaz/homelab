resource "proxmox_virtual_environment_file" "user_data_cloud_config" {
  content_type = "snippets"
  datastore_id = var.snippets_datastore_id
  node_name    = var.node_name

  source_raw {
    data = "#cloud-config\n${yamlencode({
      hostname       = var.vm_name
      timezone       = var.timezone
      disable_root   = true
      ssh_pwauth     = false
      ssh_deletekeys = true
      package_update = true
      packages       = ["qemu-guest-agent"]
      users = [
        {
          name                = var.ssh_username
          groups              = ["sudo"]
          shell               = "/bin/bash"
          lock_passwd         = true
          ssh_authorized_keys = var.ssh_public_keys
          sudo                = "ALL=(ALL) NOPASSWD:ALL"
        }
      ]
      runcmd = [
        ["systemctl", "enable", "--now", "qemu-guest-agent"]
      ]
    })}"

    file_name = "${var.vm_name}-user-data-cloud-config.yaml"
  }
}
