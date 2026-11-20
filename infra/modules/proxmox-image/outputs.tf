output "image_id" {
  description = "Downloaded Proxmox image identifier"
  value       = proxmox_download_file.image.id
}


output "image_filename" {
  description = "Downloaded image filename"
  value       = local.image_filename
}
