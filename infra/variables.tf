variable "tags" {
  description = "Additional Proxmox tags"
  type        = set(string)
  default     = []
  nullable    = false
}

variable "proxmox_endpoint" {
  description = "Proxmox API endpoint URL, for example https://192.168.1.10:8006/"
  type        = string
  nullable    = false
}

variable "proxmox_api_token" {
  description = "Proxmox API token in user@realm!token-id=secret format"
  type        = string
  sensitive   = true
}

variable "proxmox_node_name" {
  description = "Existing Proxmox node on which to create the cloud image, template and VMs"
  type        = string
  nullable    = false
}

variable "proxmox_files_datastore_id" {
  description = "Existing Proxmox datastore for cloud images and cloud-init snippets; must support import and snippets content types"
  type        = string
  default     = "local"
  nullable    = false
}

variable "proxmox_vms_datastore_id" {
  description = "Existing datastore supporting VM disks; used for the boot, EFI and cloud-init disks"
  type        = string
  default     = "local-lvm"
  nullable    = false
}

variable "k8s_cloud_image" {
  type = object({
    url          = string
    content_type = optional(string, "import")
    datastore_id = optional(string, "local")
  })
}

##############################################################################
# VM Template
##############################################################################

variable "template_vm_id" {
  description = "Unique template VM ID in the Proxmox cluster, for example 9000"
  type        = number
  nullable    = false
}

variable "vm_template_name" {
  description = "Template name; use a versioned name when publishing a new base image"
  type        = string
  nullable    = false
}

variable "template_cpu" {
  description = "Template CPU model, sockets and cores per socket; host favors performance on the current host over migration portability"

  type = object({
    type    = optional(string, "host")
    sockets = optional(number, 1)
    cores   = optional(number, 2)
  })

  default  = {}
  nullable = false
}

variable "template_memory" {
  description = "Template dedicated memory in MiB; ballooning is disabled"
  type        = number
  default     = 2048
  nullable    = false
}

variable "template_disk_size" {
  description = "Template boot disk capacity in GiB; must be at least the source image virtual size, and clones can grow it"
  type        = number
  default     = 20
  nullable    = false
}

variable "template_stop_on_destroy" {
  description = "Template Force-stop rather than request a graceful shutdown during deletion"
  type        = bool
  default     = true
  nullable    = false
}

##############################################################################
# VM & VM Template network
##############################################################################

variable "bridge" {
  description = "Existing Proxmox network bridge to attach the NIC to, for example vmbr0; this module does not create it"
  type        = string
  nullable    = false
}

variable "gateway_ip" {
  description = "Gateway for the private VM network"
  type        = string
  nullable    = false
}

variable "dns_servers" {
  description = "DNS servers for the VMs"
  type        = list(string)
  default     = ["1.1.1.1", "1.0.0.1"]
}

##############################################################################
# Kubernetes
##############################################################################

variable "ssh_username" {
  description = "Cloud-init user with passwordless sudo and SSH key access"
  type        = string
  nullable    = false
}

variable "ssh_public_key_path" {
  description = "Public SSH key file path relative to the root module"
  type        = string
  nullable    = false
}

variable "k8s_nodes" {
  description = "Control-plane and worker nodes, numbered by their position in each list"

  type = object({
    control_plane = optional(list(object({
      cpu = optional(object({
        cores   = optional(number, 2)
        sockets = optional(number, 1)
        type    = optional(string, "host")
      }), {})

      memory          = optional(number, 4096)
      storage_size    = optional(number, 30)
      private_ip_cidr = string
    })), [])

    workers = optional(list(object({
      cpu = optional(object({
        cores   = optional(number, 2)
        sockets = optional(number, 1)
        type    = optional(string, "host")
      }), {})

      memory          = optional(number, 4096)
      storage_size    = optional(number, 30)
      private_ip_cidr = string
    })), [])
  })

  nullable = false

  validation {
    condition     = length(var.k8s_nodes.control_plane) > 0
    error_message = "At least one control-plane node is required."
  }

  validation {
    condition = alltrue([
      for node in concat(
        var.k8s_nodes.control_plane,
        var.k8s_nodes.workers
      ) : can(cidrnetmask(node.private_ip_cidr))
    ])
    error_message = "Each node must have a valid IPv4 address in CIDR notation."
  }

  validation {
    condition = length(distinct([
      for node in flatten(values(var.k8s_nodes)) :
      split("/", node.private_ip_cidr)[0]
    ])) == length(flatten(values(var.k8s_nodes)))

    error_message = "Each node must have a unique IPv4 address."
  }
}
