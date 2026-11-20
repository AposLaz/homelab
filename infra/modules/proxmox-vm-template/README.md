# Proxmox VM template

Creates a stopped, unbooted Linux cloud-init template from an existing,
uncompressed cloud image. The image must be available on the target Proxmox node
with the `import` content type. The provider configuration is supplied by the
calling environment.

The module imports the image into a VM boot disk and configures CPU, memory,
networking and cloud-init so the template can be cloned into individual VMs.

## Usage

Example call from `infra/environments/kubeadm`, using the existing image module:

```hcl
module "debian_template" {
  source = "../../modules/proxmox-vm-template"

  node_name        = var.proxmox_node_name
  vm_template_name = "debian13-cloudinit-v1"
  vm_id            = 9000
  image_id         = module.debian_image.image_id
  datastore_id     = "local-lvm"
  bridge           = "vmbr0"

  cpu       = { type = "host", sockets = 1, cores = 2 }
  memory    = 2048
  disk_size = 20
  tags      = ["debian13", "kubeadm"]
}
```

Choose an unused VM ID and an existing bridge and datastore. This example is
documentation only; the module does not create bridges or storage.

## Inputs

| Variable | Type | Default | Description |
| --- | --- | --- | --- |
| `node_name` | `string` | Required | Existing Proxmox node on which to create the template. |
| `vm_template_name` | `string` | Required | Template name; use a versioned name for each new base image. |
| `vm_id` | `number` | Required | Unique VM ID across the Proxmox cluster, from 100 to 999999999. |
| `cpu` | `object({ type = optional(string, "host"), sockets = optional(number, 1), cores = optional(number, 2) })` | `{}` | CPU model, socket count and cores per socket. Omitted attributes use their defaults. |
| `memory` | `number` | `2048` | Dedicated memory in MiB, at least 512; ballooning is disabled. |
| `image_id` | `string` | Required | Existing uncompressed cloud image on the target node, in `datastore:import/filename` format. |
| `datastore_id` | `string` | `"local-lvm"` | Existing datastore for boot, EFI and cloud-init disks. |
| `disk_size` | `number` | `20` | Boot disk capacity in GiB; must be at least the source image's virtual size. |
| `bridge` | `string` | Required | Existing Proxmox network bridge for the VirtIO NIC, for example `vmbr0`. |
| `tags` | `set(string)` | `[]` | Additional tags; `vm_template` and `managed-by-tofu` are added automatically. |
| `stop_on_destroy` | `bool` | `true` | Force-stop the template instead of requesting a graceful shutdown during deletion. |

The template uses Q35, UEFI with pre-enrolled Secure Boot keys, VirtIO SCSI
single, a SCSI boot disk with I/O thread and discard enabled, a VirtIO NIC and a
serial console. Select a shared CPU model instead of `host` if migration between
different physical CPUs is needed.

## Cloning and guest configuration

CPU, memory and disk size here define the template's baseline. The
`proxmox-vm` module explicitly configures each clone's CPU model, socket count,
cores per socket, dedicated memory and boot disk options. Changing those clone inputs
does not modify the template. Clone disks must be at least as large as the
template disk; shrinking is not supported.

Outputs `template_vm_id`, `template_node_name` and `template_name` identify the
template for a future VM module. Supply unique names, addresses, users and public
SSH keys on each clone. DHCP is only a generic template default. The template has
no configured login credentials; set clone access before starting it.

The guest agent is disabled because this module does not install guest packages.
Install and start `qemu-guest-agent` on clones before relying on it for IP
discovery or guest operations. If enabling it as part of clone creation, ensure
the clone's initialization installs and starts it.

This module does not boot or customize the image, install containerd or Kubernetes,
disable guest swap, or run `kubeadm init` / `join`. Configure those on the clones.
Verify that clones receive unique machine IDs, MAC addresses, product UUIDs and
SSH host keys before building the cluster. When overriding a cloned disk block,
also retain the desired nondefault disk options such as discard and I/O thread.

## References

- [VM resource documentation for provider 0.120.0](https://registry.terraform.io/providers/bpg/proxmox/0.120.0/docs/resources/virtual_environment_vm)
- [Provider cloud-init guide for 0.120.0](https://github.com/bpg/terraform-provider-proxmox/blob/v0.120.0/docs/guides/cloud-init.md)
- [Kubeadm prerequisites](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
