# Homelab

Provision Debian Kubernetes VMs on Proxmox with OpenTofu/Terraform, configure them with Ansible and kubeadm, and install Cilium, Hubble, and Argo CD through Helm.

This repository describes a personal homelab. Adapt the inventory, networking, storage, versions, and local paths before running it. The current kubeadm workflow targets **one control-plane node** and multiple workers; it does not implement a highly available control plane.

## Architecture

[![Homelab architecture: management tools, home Wi-Fi network, Proxmox private bridge and NAT, four Debian Kubernetes VMs, and Cilium, Hubble, and Argo CD.](docs/diagrams/homelab.svg?v=2)](docs/diagrams/homelab.svg)

Click the diagram to view it at full size.

The diagram shows the repository configuration, not live deployment status. Solid arrows show network connectivity and the outbound traffic path; dashed arrows show provisioning and configuration. Argo CD is bootstrapped; Git repositories and Applications still need to be configured.

To add a service, open the [editable draw.io source](docs/diagrams/homelab.drawio) in [draw.io](https://app.diagrams.net/) or draw.io Desktop. Duplicate a service card, replace its logo and labels, and adjust its connections. Save the source, then use **File → Export as → SVG** to replace `docs/diagrams/homelab.svg`, with **Embed Images** enabled, a white background, and plain text labels. Commit both files together. The [diagram notes and logo sources](docs/diagrams/README.md) include asset attribution and more editing details.

## Layout

| Path | Purpose |
| --- | --- |
| `infra/` | Proxmox image download, VM template, and Kubernetes VMs |
| `infra/servers/pve01.tfvars.example` | Public example of infrastructure inputs |
| `ansible/inventories/` | Hosts, connection settings, and environment variables |
| `ansible/roles/proxmox_base/` | Proxmox packages, repositories, storage, and updates |
| `ansible/roles/proxmox_network/` | Proxmox bridge and Wi-Fi/NAT configuration |
| `ansible/roles/kubeadm/` | Container runtime, Kubernetes, Cilium, and worker joins |
| `ansible/roles/argocd/` | Argo CD bootstrap using Helm on the laptop |
| `docs/proxmox_network_architecture.md` | Network design notes |

## Requirements

- An existing Proxmox installation, accessible over SSH and its API.
- Existing datastores for VM disks and cloud images/snippets. Defaults use `local-lvm` and `local`; verify their supported content types.
- A Proxmox API token with permissions appropriate to the resources being created, plus SSH access as required by the provider.
- A Linux management machine with OpenTofu 1.10+ or compatible Terraform, Python, Ansible, Helm, kubectl, and an SSH client/agent.
- Internet access from the management machine, Proxmox, and VMs for packages, charts, and container images.
- Available VM IDs, IP addresses, CPU, memory, and disk space. The example creates a template, one control plane, and three workers.

`ansible/requirements.txt` specifies the Ansible distribution. Helm modules require the `kubernetes.core` collection. The inventory currently selects Python 3.13 on remote hosts; adjust that interpreter path for your OS images.

## Network assumptions

The supplied environment uses a private VM bridge behind a Proxmox host connected to the home LAN over Wi-Fi:

```text
Management laptop → Proxmox LAN IP → private VM bridge → Kubernetes nodes
```

Example values in the inventory:

| Setting | Current value |
| --- | --- |
| Proxmox LAN IP | `192.168.1.38` |
| VM subnet | `192.168.100.0/24` |
| VM gateway on Proxmox | `192.168.100.2` |
| Control-plane IP | `192.168.100.10` |
| Worker IPs | `192.168.100.11`–`192.168.100.13` |

Replace these with your own addresses. SSH ProxyJump provides SSH access; local Helm and kubectl also need a route to the Kubernetes API on port 6443.

**Review `network.yml` before applying it.** The networking role replaces `/etc/network/interfaces` and `/etc/nftables.conf`; the supplied nftables template flushes existing rules and uses permissive filter policies. Have console access and adapt it before using it on a host with an existing firewall or different network design. The laptop route playbook reactivates its NetworkManager connection and can briefly interrupt connectivity.

## 1. Customize the environment

Create your private infrastructure inputs from the example:

```bash
cd infra
cp servers/pve01.tfvars.example servers/pve01.tfvars
```

Edit the copied file: Proxmox endpoint and node name, datastore choices, cloud-image URL, bridge, gateway, template ID, VM resources, and addresses. Confirm that the pinned image URL is available. Real `infra/servers/*.tfvars` files are ignored by Git.

Create the VM SSH key if you do not already have one, from `infra/`:

```bash
mkdir -p .ssh
ssh-keygen -t ed25519 -f .ssh/vms
```

The provider uses an SSH agent for its Proxmox connection. Load the separate key you use to access the Proxmox host into your SSH agent and verify SSH access before provisioning.

Customize these Ansible files to match the infrastructure inputs:

| File | What to change |
| --- | --- |
| `inventories/hosts.yaml` | Proxmox/node IPs, SSH usernames, key path, ProxyJump, Python paths, and laptop NetworkManager profile |
| `inventories/host_vars/pve01.yaml` | Proxmox interfaces, bridge, gateway, and network mode |
| `inventories/group_vars/proxmox.yml` | VM IDs and host settings |
| `inventories/group_vars/kubeadm_cluster.yml` | Component versions/checksums, Cilium settings, `cilium.kubeconfig`, and `argo` settings |

Keep VM names consistent with the inventory: infrastructure generates `control-plane-01`, `worker-01`, and so on. The public example uses an illustrative Proxmox IP that differs from the personal inventory; update both.

## 2. Prepare Ansible

From the repository root, create a local environment using a Python version supported by the pinned Ansible requirement:

```bash
cd ansible
python3.13 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
ansible-galaxy collection list kubernetes.core
```

Install `kubernetes.core` with `ansible-galaxy collection install kubernetes.core` if it is missing. Helm and kubectl must be installed separately on your laptop.

Alternatively, inspect and run `bash setup.sh` from `ansible/`. It uses APT, requires Python 3.13 packages, and deletes/recreates `ansible/.venv`. It does not install Helm or kubectl.

Run all following Ansible commands **from `ansible/`** so its `ansible.cfg` resolves the inventory and roles correctly.

## 3. Prepare Proxmox

Review the roles, then apply the base configuration and your adapted network configuration:

```bash
ansible-playbook playbooks/proxmox.yml
ansible-playbook playbooks/network.yml
```

The base role changes package repositories and unattended-update settings and enables snippets on the `local` datastore. The optional root-level USB-tether bootstrap script is for initial host connectivity; inspect it before use. It is not needed on a host that already has working networking.

## 4. Provision the VMs

From `infra/`, supply the API token without writing it into tracked files or shell command history:

```bash
read -r -s -p 'Proxmox API token: ' TF_VAR_proxmox_api_token
printf '\n'
export TF_VAR_proxmox_api_token

tofu init
tofu validate
tofu plan -var-file=servers/pve01.tfvars
tofu apply -var-file=servers/pve01.tfvars

unset TF_VAR_proxmox_api_token
```

Review the plan before confirming apply. Terraform can be used in place of `tofu` where compatible. Protect your local state files and back them up; they are excluded from Git.

## 5. Bootstrap Kubernetes

From `ansible/`:

```bash
ansible-playbook playbooks/kubeadm.yml --tags bootstrap
```

This configures node prerequisites, containerd, crictl, Kubernetes packages, and initializes the control plane. Versions and binary checksums are pinned in group variables; update them together and verify component compatibility when changing them.

Before Cilium installation, configure laptop routing. On a NetworkManager laptop, after editing `laptop_connection` in the inventory:

```bash
ansible-playbook playbooks/laptop-network.yml --ask-become-pass
```

For other operating systems/network managers, configure an equivalent persistent route to your VM subnet via the Proxmox LAN IP.

Copy the administrator kubeconfig to your laptop. With the supplied naming/addressing, run from `ansible/`:

```bash
mkdir -p ~/.kube
chmod 700 ~/.kube
ssh -J root@192.168.1.38 -i ../infra/.ssh/vms debian@192.168.100.10 \
  'sudo cat /etc/kubernetes/admin.conf' > ~/.kube/homelab
chmod 600 ~/.kube/homelab
export KUBECONFIG="$HOME/.kube/homelab"
```

Use your own addresses/key paths. Check the file is nonempty and its API server address is reachable from the laptop. It grants administrator access: never commit it. Match the path in `cilium.kubeconfig` and `argo.kubeconfig`.

Install networking, join workers, then enable Hubble relay/UI:

```bash
ansible-playbook playbooks/kubeadm.yml --tags cilium
ansible-playbook playbooks/kubeadm.yml --tags nodes
ansible-playbook playbooks/kubeadm.yml --tags hubble

kubectl get nodes -o wide
kubectl -n kube-system get pods -o wide
```

The `nodes` tag includes token preparation on the control plane and worker joins. Include the control plane when limiting that run; workers need its runtime token/hash facts. The join task uses `/etc/kubernetes/kubelet.conf` to avoid repeating joins.

The `cilium` tag renders relay/UI as disabled. Run `hubble` afterward to enable them again, or select both with `--tags cilium,hubble`. An unfiltered kubeadm playbook runs all stages, including Hubble; use the staged sequence for initial setup because Cilium requires the local kubeconfig first.

Current values retain kube-proxy. MetalLB, Cilium L2/BGP advertisement, Ingress/Gateway, persistent storage, and application backups are not installed by this workflow.

Cilium/Hubble and Argo CD expose metrics, but create ServiceMonitors only when the Prometheus Operator ServiceMonitor CRD exists. Install the CRDs through your monitoring stack (for example, `kube-prometheus-stack`). After installing it, rerun `ansible-playbook playbooks/kubeadm.yml --tags hubble` and `ansible-playbook playbooks/argocd.yml` to enable the monitors. Configure Prometheus to select their labels and namespaces (`kube-system` and `argocd`).

## 6. Bootstrap Argo CD

Once all nodes are Ready, run from `ansible/`:

```bash
ansible-playbook playbooks/argocd.yml
```

The role runs Helm on your laptop, creates the `argocd` namespace, and installs the pinned chart with your `argo` settings. It does not install Helm on cluster nodes. Ingress is disabled initially; `argo.domain` alone does not configure DNS or expose the server.

With `KUBECONFIG` set as above:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Open `https://localhost:8080` and log in as `admin`. In another terminal, retrieve the generated initial password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
printf '\n'
```

The initial certificate may be self-signed. After changing the password and storing the replacement securely, delete the initial-password Secret. It does not track subsequent password changes.

Argo CD can manage its own cluster using `https://kubernetes.default.svc` as an Application destination; extra cluster credentials are unnecessary for that case. Git repositories and Argo CD Applications still need to be configured; this bootstrap does not create them.

## Secrets and local checks

Keep API tokens, passwords, private keys, kubeconfigs, state files, and unencrypted secret values outside Git. Use encrypted Ansible Vault variables for bootstrap secrets if needed. A Kubernetes Secret's base64 encoding is not encryption.

Install the pre-commit framework on your laptop, then activate the tracked Gitleaks configuration from the repository root:

```bash
pre-commit install
pre-commit run --all-files
```

Each clone needs `pre-commit install`. The hook scans staged changes during commits; it does not replace a full-history scan or credential rotation after a leak.

The supplied Ansible configuration disables SSH host-key checking, and the Proxmox provider disables TLS certificate verification. Review these settings and configure trusted keys/certificates for your environment before using this beyond an isolated lab.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Helm executable missing | Install Helm on the laptop and ensure it is on Ansible's local PATH |
| Local Helm cannot connect | Kubeconfig path, API server address, laptop route, and port 6443 access |
| Workers remain NotReady | `kubectl describe node <name>` and Cilium pod events/logs |
| Hubble values are disabled after a rerun | Run the `hubble` tag after `cilium` |
| NodePort reachable but ClusterIP is not | NodePort is the external entry point; the laptop route to nodes does not automatically expose Service/Pod networks |
| Ansible cannot find roles/inventory | Run playbooks from `ansible/` |

This documentation describes the repository workflow, not a fresh end-to-end deployment test on another machine.
