# Proxmox VM clone

Creates a full clone of a Linux cloud-init template. Each clone explicitly sets
its CPU, memory and boot disk configuration without changing the template.
Cloud-init creates an SSH user and installs and starts the QEMU guest agent.
The image needs cloud-init, systemd, sudo support and package repository access.

## Usage

```hcl
module "worker" {
  source = "../../modules/proxmox-vm"

  node_name      = module.debian_vm_template.template_node_name
  vm_template_id = module.debian_vm_template.template_vm_id
  vm_name        = "worker-01"

  cpu          = { type = "host", sockets = 1, cores = 4 }
  memory       = 4096
  disk_size    = 40
  datastore_id = "local-lvm"

  private_cidr_addr = "192.168.100.10/24"
  gateway_ip        = "192.168.100.2"
  dns_servers       = ["1.1.1.1", "1.0.0.1"]

  ssh_username    = "debian"
  ssh_public_keys = [trimspace(file(pathexpand("~/.ssh/homelab.pub")))]
}
```

The boot disk must be `scsi0`, as in `proxmox-vm-template`. Disk capacity can
only grow and must be at least the template's disk capacity. The clone inherits
its bridge and boot configuration from the template. VM names must be unique on
each node because they also identify the uploaded cloud-init snippets.

Assign a unique static IPv4 address to each clone. In the existing Ansible
network configuration, `192.168.100.0/24` is the private VM subnet and
`192.168.100.2` is the Proxmox gateway; do not assign the gateway address to a
VM. Ansible configures the bridge and NAT, while this module supplies each VM's
address, gateway and DNS through cloud-init. No DHCP server is required.

The public SSH key is read from the machine running OpenTofu. Generate the
example key pair at `~/.ssh/homelab` before using this example, or adjust the
public key path. Keep the private key outside Git; only the public key is
passed to the VM.

## Inputs

| Variable | Type | Default | Description |
| --- | --- | --- | --- |
| `node_name` | `string` | Required | Destination Proxmox node. |
| `vm_name` | `string` | Required | VM name and guest hostname. |
| `vm_template_id` | `number` | Required | Source template VM ID. |
| `template_node_name` | `string` | `null` | Source node; omitted uses the destination node. |
| `cpu` | `object({ type = optional(string, "host"), sockets = optional(number, 1), cores = optional(number, 2) })` | `{}` | CPU model, socket count and cores per socket; omitted attributes use their defaults. |
| `memory` | `number` | `2048` | Dedicated memory in MiB; ballooning is disabled. |
| `disk_size` | `number` | `20` | Boot disk size in GiB; cannot be smaller than the template disk. |
| `datastore_id` | `string` | `"local-lvm"` | Destination storage for cloned disks and cloud-init. |
| `tags` | `set(string)` | `[]` | Additional tags alongside `cloned_vm` and `managed-by-tofu`. |
| `private_cidr_addr` | `string` | Required | VM IPv4 address with a CIDR prefix, for example `192.168.100.10/24`. |
| `gateway_ip` | `string` | Required | IPv4 gateway without a CIDR prefix, for example `192.168.100.2`. |
| `dns_servers` | `list(string)` | `["1.1.1.1", "1.0.0.1"]` | Nonempty list of IPv4 DNS server addresses without CIDR prefixes. |
| `snippets_datastore_id` | `string` | `"local"` | Existing datastore with snippets support. |
| `ssh_username` | `string` | `"debian"` | Guest user with key access and passwordless sudo. |
| `ssh_public_keys` | `list(string)` | Required | At least one public SSH key for the guest user. |
| `timezone` | `string` | `"Etc/UTC"` | Guest timezone. |

Network validation checks address formats. It does not check IP availability,
whether the gateway is in the VM's subnet, or DNS reachability. CPU cores and
sockets must be positive whole numbers; total vCPUs are sockets times cores.

The provider must have permission to upload snippets, including the SSH access
required by the provider for snippet uploads. The VM starts automatically and
boots with the Proxmox host. Full cloning defaults to the same node; cross-node
cloning also depends on Proxmox storage availability.

## Outputs

| Output | Description |
| --- | --- |
| `vm_id` | ID assigned to the clone. |
| `vm_ipv4_addresses` | Guest-agent IPv4 addresses excluding loopback and link-local addresses. |
| `vm_ipv4_address` | First address from that list, or `null` if unavailable; not guaranteed to select the primary interface. |

Address outputs require the guest agent to be running. Cloud-init package
installation requires working networking. A successful apply does not establish
that all guest provisioning or application setup has completed.
