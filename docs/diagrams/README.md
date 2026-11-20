# Homelab architecture diagram

[homelab.drawio](homelab.drawio) is the editable source. [homelab.svg](homelab.svg) is its exported image, embedded in the repository README. Both contain embedded logo images and can be viewed without fetching remote assets. The initial SVG also includes a copy of the diagram data.

## Update the diagram

1. Open `homelab.drawio` in draw.io Desktop or at <https://app.diagrams.net/>. Use Desktop to edit entirely offline.
2. Expand the Kubernetes and Proxmox containers if more room is needed. Duplicate a service card to keep its logo, title, and description grouped. Double-click into a group to edit its children; replace the logo through the image shape's image picker. Local originals are in `assets/`.
3. Update labels and connections to match the repository configuration. Solid gray arrows describe the network and outbound path; dashed purple arrows describe provisioning and configuration. Use the matching connector style when adding relationships. Keep the single control plane and Argo CD bootstrap status accurate.
4. Save the `.drawio` source. Use **File → Export as → SVG**, enable **Embed Images** and **Include a copy of my diagram**, and export the full page with a white background and no extra border. Keep text labels plain so they render without HTML support.
5. Replace `homelab.svg` and inspect it at README width. Check for missing logos, clipped text, overlapping connections, and stale addresses. Commit the source and export together.

Adding an image to `assets/` alone does not change the diagram: replace or insert the image shape in draw.io, then export again. Add the new image's upstream source and applicable attribution below. No automatic discovery or regeneration is configured.

## Logo sources and attribution

The files below are copies of official upstream artwork. Logos retain their original colors and proportions. They identify the software used in this homelab; they do not imply endorsement. Copyright and trademark rights remain with their respective owners. The download URLs and SHA-256 hashes are recorded in [assets/sources.json](assets/sources.json).

| Local asset | Official source | Attribution / terms |
| --- | --- | --- |
| [OpenTofu](assets/opentofu.svg) | [OpenTofu brand artifacts](https://github.com/opentofu/brand-artifacts/tree/main/symbol-only/transparent/SVG) | Copyright The OpenTofu Authors; [Mozilla Public License 2.0 and trademark notice](assets/OPENTOFU-LICENSE.txt), copied from upstream. Color symbol for light backgrounds. |
| [Ansible](assets/ansible.svg) | [Ansible community logo](https://github.com/ansible/logos/tree/main/community-logo) | Ansible community / Red Hat; [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) and upstream [trademark terms](https://github.com/ansible/logos/blob/main/TRADEMARKS.md). |
| [Helm](assets/helm.svg) | [CNCF Helm artwork](https://github.com/cncf/artwork/tree/main/projects/helm) | Helm project / CNCF; see the [artwork repository](https://github.com/cncf/artwork) for usage terms. |
| [Kubernetes / kubectl](assets/kubernetes.svg) | [CNCF Kubernetes artwork](https://github.com/cncf/artwork/tree/main/projects/kubernetes) | Kubernetes project / CNCF. The Kubernetes mark also identifies its kubectl CLI; this is not a separate kubectl logo. See [artwork usage terms](https://github.com/cncf/artwork). |
| [Proxmox](assets/proxmox.svg) | [Proxmox media kit](https://www.proxmox.com/en/about/media-kit) | Proxmox Server Solutions GmbH. Full color lockup from the official logo pack; see the media kit and included brand guidelines. |
| [Debian](assets/debian.svg) | [Debian Open Use Logo](https://www.debian.org/logos/) | Copyright © 1999 Software in the Public Interest, Inc.; logo by Raul Silva. Used under [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/), one of the upstream license options. Learn more at [debian.org](https://www.debian.org/). |
| [Cilium](assets/cilium.svg) | [CNCF Cilium artwork](https://github.com/cncf/artwork/tree/main/projects/cilium) | Cilium project / CNCF; see [artwork usage terms](https://github.com/cncf/artwork). |
| [Hubble](assets/hubble.png) | [Official Hubble repository](https://github.com/cilium/hubble/blob/main/Documentation/images/hubble_logo.png) | Cilium / Hubble contributors; see the upstream [repository and license](https://github.com/cilium/hubble). Original PNG wordmark. |
| [Argo CD](assets/argo.svg) | [CNCF Argo artwork](https://github.com/cncf/artwork/tree/main/projects/argo) | Argo project / CNCF. The Argo mark identifies Argo CD here; see [artwork usage terms](https://github.com/cncf/artwork). |

## Configuration references

The layout follows the [Ansible inventory](../../ansible/inventories/hosts.yaml), [Proxmox host variables](../../ansible/inventories/host_vars/pve01.yaml), and [cluster variables](../../ansible/inventories/group_vars/kubeadm_cluster.yml). Cilium and Argo CD behavior follows their role templates. The diagram intentionally omits component versions to avoid duplicating version pins.

The private bridge has no physical ports. Outbound VM traffic passes through the Proxmox gateway, nftables masquerading, and Wi-Fi uplink. The laptop needs a route through Proxmox to reach the VM subnet; SSH uses ProxyJump. The diagram does not imply general inbound NAT access, an HA control plane, configured Argo CD applications, or installed ingress, storage, and backup services.
