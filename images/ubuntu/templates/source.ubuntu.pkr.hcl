source "qemu" "image" {
  # Use cloud image URL directly from image_properties_map
  iso_url = local.cloud_image_url != "" ? local.cloud_image_url : (
    try(local.image_properties_map["ubuntu24"].cloud_image_url, "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img")
  )
  iso_checksum = local.cloud_image_checksum
  disk_image = true

  output_directory = var.output_directory
  disk_size        = coalesce(var.disk_size, "${local.os_disk_size_gb}G")
  format           = var.format

  cpus   = var.cpus
  memory = var.memory

  net_device     = var.net_device
  disk_interface = var.disk_interface
  headless       = var.headless

  ssh_username = "packer"
  ssh_password = "packer"
  ssh_timeout  = var.ssh_timeout
  cd_files = ["./cidata/*"]
  cd_label = "cidata"

  # Cloud-init configuration for cloud images
  # Note: Ubuntu cloud images typically have SSH enabled by default with user 'ubuntu'
  # If custom user/password is needed, use cd_files to provide cloud-init config

  # Cloud images boot faster as they don't need installation
  boot_wait        = var.use_cloud_image ? "30s" : "5s"
  shutdown_command = "sudo shutdown -P now"
  vm_name          = var.image_os != "" ? "ubuntu-${var.image_os}" : "ubuntu"

  qemuargs = [
    ["-display", "none"],
    ["-monitor", "none"],
    ["-machine", "type=q35,accel=hvf:kvm:whpx:tcg:none"],
    ["-cpu", "host"]
  ]
}
