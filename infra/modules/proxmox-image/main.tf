locals {
  image_filename = basename(var.image.url)
}

resource "proxmox_download_file" "image" {
  node_name    = var.node_name
  content_type = var.image.content_type
  datastore_id = var.image.datastore_id
  url          = var.image.url
  file_name    = local.image_filename
}
