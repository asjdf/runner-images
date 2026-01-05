// Proxmox authentication related variables
variable "proxmox_url" {
  type    = string
  default = "${env("PROXMOX_URL")}"
  description = "Proxmox API URL (e.g., https://proxmox.example.com:8006/api2/json)"
}
variable "proxmox_username" {
  type    = string
  default = "${env("PROXMOX_USERNAME")}"
  description = "Proxmox username (e.g., root@pam)"
}
variable "proxmox_password" {
  type      = string
  default   = "${env("PROXMOX_PASSWORD")}"
  sensitive = true
  description = "Proxmox password"
}
variable "proxmox_insecure_skip_tls_verify" {
  type    = bool
  default = false
  description = "Skip TLS verification for Proxmox API"
}
variable "proxmox_node" {
  type    = string
  default = "${env("PROXMOX_NODE")}"
  description = "Proxmox node name where VM will be created"
}
variable "proxmox_pool" {
  type    = string
  default = "${env("PROXMOX_POOL")}"
  description = "Proxmox resource pool (optional)"
}

// VM configuration variables
variable "vm_name" {
  type    = string
  default = "${env("VM_NAME")}"
  description = "Name of the VM to create"
}
variable "vm_id" {
  type    = number
  default = null
  description = "VM ID (auto-generated if not specified)"
}
variable "template_description" {
  type    = string
  default = "Built by Packer"
  description = "Template description"
}
variable "vm_cores" {
  type    = number
  default = 4
  description = "Number of CPU cores"
}
variable "vm_memory" {
  type    = number
  default = 8192
  description = "Memory in MB"
}
variable "vm_disk_size" {
  type    = string
  default = "100G"
  description = "Disk size (e.g., 100G)"
}
variable "vm_disk_storage" {
  type    = string
  default = "${env("PROXMOX_DISK_STORAGE")}"
  description = "Storage pool for disk"
}
variable "vm_disk_type" {
  type    = string
  default = "scsi"
  description = "Disk type (scsi, virtio, ide)"
}
variable "vm_network_bridge" {
  type    = string
  default = "vmbr0"
  description = "Network bridge"
}
variable "vm_network_model" {
  type    = string
  default = "virtio"
  description = "Network adapter model (virtio, e1000, rtl8139)"
}

// Clone configuration
variable "clone_vm" {
  type    = string
  default = "${env("CLONE_VM")}"
  description = "Name of the VM or template to clone from"
}
variable "clone_vm_id" {
  type    = number
  default = null
  description = "ID of the VM or template to clone from (optional, will use clone_vm name if not set)"
}
variable "full_clone" {
  type    = bool
  default = true
  description = "Create a full clone (true) or linked clone (false)"
}

// WinRM configuration
variable "winrm_username" {
  type    = string
  default = "packer"
  description = "WinRM username"
}
variable "winrm_password" {
  type      = string
  default   = "${env("WINRM_PASSWORD")}"
  sensitive = true
  description = "WinRM password"
}
variable "winrm_insecure" {
  type    = bool
  default = true
  description = "Allow insecure WinRM connections"
}
variable "winrm_use_ssl" {
  type    = bool
  default = true
  description = "Use SSL for WinRM"
}
variable "winrm_timeout" {
  type    = string
  default = "5m"
  description = "WinRM connection timeout"
}

// Advanced VM options
variable "qemu_agent" {
  type    = bool
  default = true
  description = "Enable QEMU guest agent"
}
variable "scsi_controller" {
  type    = string
  default = "virtio-scsi-single"
  description = "SCSI controller type"
}

// Image related variables
variable "agent_tools_directory" {
  type    = string
  default = "C:\\hostedtoolcache\\windows"
}
variable "helper_script_folder" {
  type    = string
  default = "C:\\Program Files\\WindowsPowerShell\\Modules\\"
}
variable "image_folder" {
  type    = string
  default = "C:\\image"
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
  default = "C:\\imagedata.json"
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
variable "temp_dir" {
  type    = string
  default = "D:\\temp"
}
