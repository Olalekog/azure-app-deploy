resource "azurerm_public_ip" "frontend" {
  name                = "pip-frontend-${local.name_prefix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${local.name_prefix}-${random_string.suffix.result}"
  tags                = var.tags
}

resource "azurerm_lb" "frontend" {
  name                = "lb-frontend-${local.name_prefix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.frontend.id
  }
}

resource "azurerm_lb_backend_address_pool" "frontend" {
  name            = "frontend-pool"
  loadbalancer_id = azurerm_lb.frontend.id
}

resource "azurerm_lb_probe" "frontend" {
  name                = "http-health"
  loadbalancer_id     = azurerm_lb.frontend.id
  protocol            = "Http"
  port                = 80
  request_path        = "/health"
  interval_in_seconds = 10
  number_of_probes    = 3
}

resource "azurerm_lb_rule" "frontend_http" {
  name                           = "http"
  loadbalancer_id                = azurerm_lb.frontend.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend-ip"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.frontend.id]
  probe_id                       = azurerm_lb_probe.frontend.id
}

resource "azurerm_user_assigned_identity" "frontend" {
  name                = "id-frontend-${local.name_prefix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "frontend_blob_read" {
  # Scoped to just this environment's release container, not the whole (shared) storage account.
  scope                = "${data.azurerm_storage_account.main.id}/blobServices/default/containers/${azurerm_storage_container.frontend_releases.name}"
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.frontend.principal_id
}

resource "azurerm_linux_virtual_machine_scale_set" "frontend" {
  name                = "vmss-frontend-${local.name_prefix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  sku                 = var.frontend_vm_size
  instances           = var.frontend_instance_count
  admin_username      = var.admin_username
  upgrade_mode        = "Automatic"
  tags                = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.frontend.id]
  }

  network_interface {
    name    = "nic-frontend"
    primary = true

    ip_configuration {
      name                                   = "ipconfig-frontend"
      primary                                = true
      subnet_id                              = azurerm_subnet.frontend.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.frontend.id]
    }
  }

  custom_data = base64encode(templatefile("${path.module}/scripts/frontend-cloud-init.yaml.tpl", {
    storage_account_name   = data.azurerm_storage_account.main.name
    release_container_name = azurerm_storage_container.frontend_releases.name
    backend_lb_ip          = var.backend_lb_private_ip
  }))

  depends_on = [azurerm_role_assignment.frontend_blob_read]
}

resource "azurerm_monitor_autoscale_setting" "frontend" {
  name                = "autoscale-frontend-${local.name_prefix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.frontend.id
  tags                = var.tags

  profile {
    name = "default"

    capacity {
      default = var.frontend_instance_count
      minimum = var.frontend_instance_count
      maximum = var.frontend_instance_max
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.frontend.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.frontend.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}
