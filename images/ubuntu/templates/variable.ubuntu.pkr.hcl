// QEMU configuration variables
variable "use_cloud_image" {
  type        = bool
  default     = true
  description = "Use Ubuntu cloud image instead of ISO (recommended). Cloud images are pre-installed and boot faster."
}
variable "cloud_image_url" {
  type        = string
  default     = ""
  description = "URL to the cloud image (if empty, will use default based on image_os). Supported: ubuntu20, ubuntu22, ubuntu24"
}
variable "cloud_image_checksum" {
  type        = string
  default     = ""
  description = "Checksum of the cloud image file (e.g., sha256:abc123...). Optional but recommended for verification."
}
variable "iso_url" {
  type        = string
  default     = "${env("ISO_URL")}"
  description = "URL to the ISO image to use for building the VM (if use_cloud_image is false)"
}
variable "iso_checksum" {
  type        = string
  default     = "${env("ISO_CHECKSUM")}"
  description = "Checksum of the ISO file (e.g., sha256:abc123...)"
}
variable "iso_checksum_type" {
  type        = string
  default     = "sha256"
  description = "Type of checksum (md5, sha1, sha256, sha512)"
}
variable "output_directory" {
  type        = string
  default     = "${env("OUTPUT_DIRECTORY")}"
  description = "Directory to store the output image"
}
variable "disk_size" {
  type        = string
  default     = null
  description = "Disk size (e.g., 75G). If null, will use value from locals based on image_os"
}
variable "format" {
  type        = string
  default     = "qcow2"
  description = "Output format for the disk image (qcow2, raw)"
}
variable "cpus" {
  type        = number
  default     = 4
  description = "Number of CPU cores"
}
variable "memory" {
  type        = number
  default     = 8192
  description = "Memory in MB"
}
variable "net_device" {
  type        = string
  default     = "virtio-net"
  description = "Network device type (virtio-net, e1000, rtl8139)"
}
variable "disk_interface" {
  type        = string
  default     = "virtio"
  description = "Disk interface type (virtio, ide, scsi)"
}
variable "headless" {
  type        = bool
  default     = true
  description = "Run QEMU in headless mode"
}

// SSH configuration
variable "ssh_timeout" {
  type        = string
  default     = "10m"
  description = "SSH connection timeout"
}

// Image related variables
variable "dockerhub_login" {
  type    = string
  default = "${env("DOCKERHUB_LOGIN")}"
}
variable "dockerhub_password" {
  type    = string
  default = "${env("DOCKERHUB_PASSWORD")}"
}
variable "helper_script_folder" {
  type    = string
  default = "/imagegeneration/helpers"
}
variable "image_folder" {
  type    = string
  default = "/imagegeneration"
}
variable "image_os" {
  type    = string
  default = ""
}
variable "image_version" {
  type    = string
  default = "dev"
}
variable "imagedata_file" {
  type    = string
  default = "/imagegeneration/imagedata.json"
}
variable "installer_script_folder" {
  type    = string
  default = "/imagegeneration/installers"
}
variable "install_password" {
  type      = string
  default   = ""
  sensitive = true
}
variable "install_user" {
  type    = string
  default = "installer"
}
