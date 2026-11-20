# Identity and placement: template name, unique VM ID and existing Proxmox node.

variable "node_name" {
  description = "Existing Proxmox node on which to create the template"
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.node_name)) > 0
    error_message = "node_name must not be empty."
  }
}

variable "vm_template_name" {
  description = "Template name; use a versioned name when publishing a new base image"
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.vm_template_name)) > 0
    error_message = "vm_template_name must not be empty."
  }
}

variable "vm_id" {
  description = "Unique template VM ID in the Proxmox cluster, for example 9000"
  type        = number
  nullable    = false

  validation {
    condition     = var.vm_id >= 100 && var.vm_id <= 999999999 && floor(var.vm_id) == var.vm_id
    error_message = "vm_id must be a whole number between 100 and 999999999."
  }
}

##############################################################################
# Resources: baseline CPU and memory that individual clones can override.
##############################################################################

variable "cpu" {
  description = "CPU model, sockets and cores per socket; host favors performance on the current host over migration portability"

  type = object({
    type    = optional(string, "host")
    sockets = optional(number, 1)
    cores   = optional(number, 2)
  })

  default  = {}
  nullable = false

  validation {
    condition = (
      var.cpu.cores >= 1 && floor(var.cpu.cores) == var.cpu.cores &&
      var.cpu.sockets >= 1 && floor(var.cpu.sockets) == var.cpu.sockets &&
      length(trimspace(var.cpu.type)) > 0
    )
    error_message = "CPU cores and sockets must be positive whole numbers, and CPU type must not be empty."
  }
}

variable "memory" {
  description = "Dedicated memory in MiB; ballooning is disabled"
  type        = number
  default     = 2048
  nullable    = false

  validation {
    condition     = var.memory >= 512 && floor(var.memory) == var.memory
    error_message = "memory must be a whole number of at least 512 MiB."
  }
}

##############################################################################
# Storage: existing cloud image, destination datastore and boot disk capacity.
##############################################################################

variable "image_id" {
  description = "Uncompressed cloud disk image ID on the target node, for example local:import/debian.qcow2"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[^:[:space:],=]+:import/[^[:space:],=]+$", var.image_id))
    error_message = "image_id must reference an uncompressed import image in the form datastore:import/filename."
  }
}

variable "datastore_id" {
  description = "Existing datastore supporting VM disks; used for the boot, EFI and cloud-init disks"
  type        = string
  default     = "local-lvm"
  nullable    = false

  validation {
    condition     = length(trimspace(var.datastore_id)) > 0
    error_message = "datastore_id must not be empty."
  }
}

variable "disk_size" {
  description = "Boot disk capacity in GiB; must be at least the source image virtual size, and clones can grow it"
  type        = number
  default     = 20
  nullable    = false

  validation {
    condition     = var.disk_size >= 1 && floor(var.disk_size) == var.disk_size
    error_message = "disk_size must be a positive whole number of GiB."
  }
}

##############################################################################
# Network: attach the VirtIO NIC to an existing bridge; clones set their IPs.
##############################################################################

variable "bridge" {
  description = "Existing Proxmox network bridge to attach the NIC to, for example vmbr0; this module does not create it"
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.bridge)) > 0
    error_message = "bridge must not be empty."
  }
}

# Metadata: additional tags alongside the module's built-in management tags.

variable "tags" {
  description = "Additional Proxmox tags for the template"
  type        = set(string)
  default     = []
  nullable    = false
}

# Lifecycle: behavior when deleting the managed template.

variable "stop_on_destroy" {
  description = "Force-stop rather than request a graceful shutdown during deletion"
  type        = bool
  default     = true
  nullable    = false
}
