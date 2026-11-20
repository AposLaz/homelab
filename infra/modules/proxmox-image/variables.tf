variable "node_name" {
  description = "Proxmox node name"
  type        = string
}

variable "image" {
  description = "Cloud image configuration"

  type = object({
    url          = string
    content_type = optional(string, "import")
    datastore_id = optional(string, "local")
  })

  validation {
    condition = contains(
      ["import", "iso"],
      var.image.content_type
    )
    error_message = "content_type must be import or iso."
  }
}
