###############################################################################
# Outputs — Unraid Docker
###############################################################################

output "running_containers" {
  description = "Names and status of managed Docker containers on Mercado"
  value = {
    audiobookshelf     = docker_container.audiobookshelf.name
    pihole             = docker_container.pihole.name
    heimdall           = docker_container.heimdall.name
    jellyfin           = docker_container.jellyfin.name
    mariadb            = docker_container.mariadb.name
    nginx_proxy_manager = docker_container.nginx_proxy_manager.name
    plex               = docker_container.plex.name
    cloudflared        = docker_container.cloudflared.name
  }
}

output "stopped_containers" {
  description = "Stopped containers tracked in Terraform state"
  value = {
    macinabox       = docker_container.macinabox.name
    postgres_immich = docker_container.postgres_immich.name
  }
}

output "service_urls" {
  description = "Local URLs for services running on Mercado"
  value = {
    jellyfin            = "http://192.168.1.24:8096"
    plex                = "http://192.168.1.24:32400/web"
    heimdall            = "http://192.168.1.24:8088"
    nginx_proxy_manager = "http://192.168.1.24:7818"
    audiobookshelf      = "http://192.168.1.24:13378"
    pihole              = "http://192.168.1.3/admin"
    mariadb             = "mysql://192.168.1.24:3306"
  }
}
