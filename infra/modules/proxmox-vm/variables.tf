# Identity and placement: VM name, destination node and source template.

variable "node_name" {
  description = "Existing Proxmox node on which to create the clone"
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.node_name)) > 0
    error_message = "node_name must not be empty."
  }
}

variable "vm_name" {
  description = "VM name"
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.vm_name)) > 0
    error_message = "vm_name must not be empty."
  }
}

variable "vm_template_id" {
  description = "Unique template VM ID in the Proxmox cluster, for example 9000"
  type        = number
  nullable    = false

  validation {
    condition     = var.vm_template_id >= 100 && var.vm_template_id <= 999999999 && floor(var.vm_template_id) == var.vm_template_id
    error_message = "vm_template_id must be a whole number between 100 and 999999999."
  }
}

variable "template_node_name" {
  description = "Source template node; null uses the destination node"
  type        = string
  default     = null
}

##############################################################################
# Resources: CPU topology and dedicated memory for each clone.
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
# Storage: destination datastores and cloned boot disk capacity.
##############################################################################

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
  description = "Boot disk capacity in GiB; must be at least the source image virtual size"
  type        = number
  default     = 20
  nullable    = false

  validation {
    condition     = var.disk_size >= 1 && floor(var.disk_size) == var.disk_size
    error_message = "disk_size must be a positive whole number of GiB."
  }
}

variable "snippets_datastore_id" {
  description = "Existing datastore supporting snippets on the destination node"
  type        = string
  default     = "local"
  nullable    = false
}

##############################################################################
# Network: IPv4 & DNS configuration for the cloned VM.
##############################################################################

variable "gateway_ip" {
  description = "Gateway ip address"
  type        = string
  nullable    = false

  validation {
    condition     = can(cidrnetmask("${var.gateway_ip}/32"))
    error_message = "gateway_ip must be a valid IPv4 address without a CIDR prefix, for example 192.168.100.2."
  }
}

variable "private_cidr_addr" {
  description = "VM IPv4 address in CIDR notation"
  type        = string
  nullable    = false

  validation {
    condition     = can(cidrnetmask(var.private_cidr_addr))
    error_message = "private_cidr_addr must be a valid IPv4 address in CIDR notation, for example 192.168.100.10/24."
  }
}

variable "dns_servers" {
  description = "DNS servers for the clone"
  type        = list(string)
  default     = ["1.1.1.1", "1.0.0.1"]
  nullable    = false

  validation {
    condition = length(var.dns_servers) > 0 && alltrue([
      for server in var.dns_servers :
      can(cidrnetmask("${server}/32"))
    ])
    error_message = "dns_servers must contain at least one valid IPv4 address without a CIDR prefix."
  }
}

##############################################################################
# Guest configuration: SSH access and timezone supplied through cloud-init.
##############################################################################

variable "ssh_username" {
  description = "Cloud-init user with passwordless sudo and SSH key access"
  type        = string
  default     = "debian"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]*$", var.ssh_username))
    error_message = "ssh_username must be a valid Linux username."
  }
}

variable "ssh_public_keys" {
  description = "Public SSH keys authorized for the cloud-init user"
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.ssh_public_keys) > 0 && alltrue([for key in var.ssh_public_keys : length(trimspace(key)) > 0])
    error_message = "Provide at least one nonempty public SSH key."
  }
}

variable "timezone" {
  description = "Guest timezone recognized by the image"
  type        = string
  default     = "Etc/UTC"
  nullable    = false
}

# Metadata: additional tags alongside the module's built-in management tags.

variable "tags" {
  description = "Additional Proxmox tags for the vm"
  type        = set(string)
  default     = []
  nullable    = false
}
