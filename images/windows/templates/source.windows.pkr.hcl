source "proxmox-clone" "image" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  password                 = var.proxmox_password
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node
  pool                     = var.proxmox_pool

  vm_name                  = var.vm_name
  vm_id                    = var.vm_id
  template_description     = var.template_description
  clone_vm                 = var.clone_vm
  clone_vm_id              = var.clone_vm_id
  full_clone               = var.full_clone
  
  cores                    = var.vm_cores
  memory                   = var.vm_memory
  
  disks {
    type         = var.vm_disk_type
    storage_pool = var.vm_disk_storage
    disk_size    = var.vm_disk_size
  }
  
  network_adapters {
    bridge = var.vm_network_bridge
    model  = var.vm_network_model
  }

  communicator              = "winrm"
  winrm_username            = var.winrm_username
  winrm_password            = var.winrm_password
  winrm_insecure            = var.winrm_insecure
  winrm_use_ssl             = var.winrm_use_ssl
  winrm_timeout             = var.winrm_timeout

  qemu_agent                = var.qemu_agent
  scsi_controller           = var.scsi_controller
}
