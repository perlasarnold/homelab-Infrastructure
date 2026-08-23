###############################################################################
# Outputs — Proxmox
###############################################################################

output "lxc_containers" {
  description = "All managed LXC containers on Bulakan"
  value = {
    wireguard           = module.wireguard.vm_id
    prowlarr            = module.prowlarr.vm_id
    plex                = module.plex.vm_id
    radarr              = module.radarr.vm_id
    sonarr              = module.sonarr.vm_id
    bazarr              = module.bazarr.vm_id
    jackett             = module.jackett.vm_id
    audiobookshelf      = module.audiobookshelf.vm_id
    photoprism          = module.photoprism.vm_id
    transmission        = module.transmission.vm_id
    heimdall_dashboard  = module.heimdall_dashboard.vm_id
    jellyfin            = module.jellyfin.vm_id
    pihole              = module.pihole.vm_id
    cloudflared         = module.cloudflared.vm_id
    netbootxyz          = module.netbootxyz.vm_id
    qbittorrent         = module.qbittorrent.vm_id
    nginxproxymanager   = module.nginxproxymanager.vm_id
    booklore            = module.booklore.vm_id
    openwrt             = module.openwrt.vm_id
  }
}

output "virtual_machines" {
  description = "All managed VMs on Bulakan"
  value = {
    perlas_w10    = proxmox_virtual_environment_vm.perlas_w10.vm_id
    immich_ubuntu = proxmox_virtual_environment_vm.immich_ubuntu.vm_id
    w11e          = proxmox_virtual_environment_vm.w11e.vm_id
    bastion       = proxmox_virtual_environment_vm.bastion.vm_id
    hack_sonoma   = proxmox_virtual_environment_vm.hack_sonoma.vm_id
    mint_dapitan  = proxmox_virtual_environment_vm.mint_desktop_dapitan.vm_id
  }
}
