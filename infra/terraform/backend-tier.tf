resource "azurerm_lb" "backend" {
  name                = "lb-backend-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                          = "backend-ip"
    subnet_id                     = azurerm_subnet.backend.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.backend_lb_private_ip
  }
}

resource "azurerm_lb_backend_address_pool" "backend" {
  name            = "backend-pool"
  loadbalancer_id = azurerm_lb.backend.id
}

resource "azurerm_lb_probe" "backend" {
  name                = "health"
  loadbalancer_id     = azurerm_lb.backend.id
  protocol            = "Http"
  port                = 8000
  request_path        = "/health"
  interval_in_seconds = 10
  number_of_probes    = 3
}

resource "azurerm_lb_rule" "backend_api" {
  name                           = "api"
  loadbalancer_id                = azurerm_lb.backend.id
  protocol                       = "Tcp"
  frontend_port                  = 8000
  backend_port                   = 8000
  frontend_ip_configuration_name = "backend-ip"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.backend.id]
  probe_id                       = azurerm_lb_probe.backend.id
}

resource "azurerm_user_assigned_identity" "backend" {
  name                = "id-backend-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "backend_blob_read" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.backend.principal_id
}

resource "azurerm_linux_virtual_machine_scale_set" "backend" {
  name                = "vmss-backend-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.backend_vm_size
  instances           = var.backend_instance_count
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
    identity_ids = [azurerm_user_assigned_identity.backend.id]
  }

  network_interface {
    name    = "nic-backend"
    primary = true

    ip_configuration {
      name                                   = "ipconfig-backend"
      primary                                = true
      subnet_id                              = azurerm_subnet.backend.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.backend.id]
    }
  }

  custom_data = base64encode(templatefile("${path.module}/scripts/backend-cloud-init.yaml.tpl", {
    storage_account_name = azurerm_storage_account.main.name
    storage_account_key  = azurerm_storage_account.main.primary_access_key
    file_share_name      = azurerm_storage_share.tododata.name
    allowed_origins      = "http://${azurerm_public_ip.frontend.fqdn}"
  }))

  depends_on = [azurerm_role_assignment.backend_blob_read]
}

resource "azurerm_monitor_autoscale_setting" "backend" {
  name                = "autoscale-backend-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.backend.id
  tags                = var.tags

  profile {
    name = "default"

    capacity {
      default = var.backend_instance_count
      minimum = var.backend_instance_count
      maximum = var.backend_instance_max
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.backend.id
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.backend.id
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
