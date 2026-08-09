output "resource_group_name" {
  value = data.azurerm_resource_group.main.name
}

output "frontend_url" {
  description = "Public URL of the app."
  value       = "http://${azurerm_public_ip.frontend.fqdn}"
}

output "frontend_public_ip" {
  value = azurerm_public_ip.frontend.ip_address
}

output "backend_internal_lb_ip" {
  description = "Private IP of the internal backend load balancer (frontend nginx proxies /api/ here)."
  value       = azurerm_lb.backend.frontend_ip_configuration[0].private_ip_address
}

output "storage_account_name" {
  value = data.azurerm_storage_account.main.name
}

output "frontend_release_container" {
  description = "Blob container the frontend Azure DevOps pipeline uploads latest.zip to."
  value       = azurerm_storage_container.frontend_releases.name
}

output "backend_release_container" {
  description = "Blob container the backend Azure DevOps pipeline uploads latest.zip to."
  value       = azurerm_storage_container.backend_releases.name
}

output "frontend_vmss_name" {
  value = azurerm_linux_virtual_machine_scale_set.frontend.name
}

output "backend_vmss_name" {
  value = azurerm_linux_virtual_machine_scale_set.backend.name
}
