locals {
  # For QEMU, we don't need marketplace SKU, but keep this for compatibility
  image_properties_map = {
    "ubuntu20" = {
      os_disk_size_gb = 75
      cloud_image_url = "https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img"
      cloud_image_checksum = "file:https://cloud-images.ubuntu.com/releases/focal/release/SHA256SUMS"
    },
    "ubuntu22" = {
      os_disk_size_gb = 75
      cloud_image_url = "https://cloud-images.ubuntu.com/releases/jammy/release/ubuntu-22.04-server-cloudimg-amd64.img"
      cloud_image_checksum = "file:https://cloud-images.ubuntu.com/releases/jammy/release/SHA256SUMS"
    },
    "ubuntu24" = {
      os_disk_size_gb = 75
      cloud_image_url = "https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64.img"
      cloud_image_checksum = "file:https://cloud-images.ubuntu.com/releases/noble/release/SHA256SUMS"
    }
  }
  
  # Cloud image checksum with file: prefix already included
  cloud_image_checksum = var.image_os != "" ? try(local.image_properties_map[var.image_os].cloud_image_checksum, "none") : "none"

  # Default disk size for QEMU (in GB, will be converted to string format like "75G")
  os_disk_size_gb = coalesce(
    try(local.image_properties_map[var.image_os].os_disk_size_gb, 75),
    75
  )

  # Cloud image URL based on image_os - directly from map, no environment variable needed
  cloud_image_url = var.image_os != "" ? try(local.image_properties_map[var.image_os].cloud_image_url, "") : ""

  # Android SDK command line tools filename from toolset
  # This matches what install-android-sdk.sh reads from toolset.json
  android_cmdline_tools_file = jsondecode(file("${path.root}/../toolsets/toolset-2404.json")).android["cmdline-tools"]
}
