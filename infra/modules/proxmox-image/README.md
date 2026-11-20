# Proxmox image

Downloads a cloud image or ISO from a URL into an existing datastore on a
Proxmox node. The filename is derived from the URL. The provider configuration
is supplied by the calling environment.

## Usage

```hcl
module "debian_image" {
  source = "../../modules/proxmox-image"

  node_name = var.proxmox_node_name
  image = {
    url = var.debian_image_url
  }
}
```

The target datastore must support the selected content type. By default, the
module stores the image as `import` content in the `local` datastore.

## Inputs

| Variable | Type | Default | Description |
| --- | --- | --- | --- |
| `node_name` | `string` | Required | Proxmox node on which to download the image. |
| `image` | `object({ url = string, content_type = optional(string, "import"), datastore_id = optional(string, "local") })` | Required | Image download configuration. `url` is required; omitted optional attributes use their defaults. |

The `image` object accepts the following attributes:

| Attribute | Type | Default | Description |
| --- | --- | --- | --- |
| `url` | `string` | Required | Download URL; its basename becomes the stored filename. |
| `content_type` | `string` | `"import"` | Proxmox content type; must be `import` or `iso`. |
| `datastore_id` | `string` | `"local"` | Existing datastore in which to store the downloaded file. |

## Outputs

| Output | Description |
| --- | --- |
| `image_id` | Downloaded Proxmox image identifier, usable as the `image_id` input of the VM template module for an import image. |
| `image_filename` | Downloaded image filename derived from the URL. |
