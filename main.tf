terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.72.0"
    }
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.51.0"
    }
  }
}

locals {
  cloud = "AZURE"
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

provider "confluent" {
  cloud_api_key    = var.ccloud_api_key
  cloud_api_secret = var.ccloud_api_secret
}

# The Confluent network for the Private Link connection
resource "confluent_network" "pl-network" {
  display_name     = "pl-net"
  cloud            = "AZURE"
  region           = var.location
  connection_types = ["PRIVATELINK"]
  environment {
    id = var.ccloud_environment_id
  }

  # This meta-argument, when set to true, will cause Terraform to reject with an
  # error any plan that would destroy the infrastructure object associated with
  # the resource.

  # This can be used as a measure of safety against the accidental replacement of
  # objects that may be costly to reproduce, such as Confluent clusters. However,
  # it will make certain configuration changes impossible to apply, and will
  # prevent the use of the terraform destroy command once such objects are
  # created, and so this option should be used sparingly or removed if there is a desire to 
  # destroy the deployment

  lifecycle {
    prevent_destroy = true
  }
}

# Needed Private Link request for access 
resource "confluent_private_link_access" "pl-access" {
  display_name = "Azure Private Link Access"
  azure {
    subscription = var.subscription_id
  }
  environment {
    id = var.ccloud_environment_id
  }
  network {
    id = confluent_network.pl-network.id
  }
}


# The dedicated kafka cluster with Private Link
resource "confluent_kafka_cluster" "dedicated-pl" {
  display_name = "pl-dedicated"
  availability = var.ccloud_cluster_availability
  cloud        = local.cloud
  region       = var.location

  dedicated {
    cku = var.ccloud_cluster_ckus
  }
  environment {
    id = var.ccloud_environment_id
  }
  network {
    id = confluent_network.pl-network.id
  }
}

# Declaring local variables and comput data variables
locals {
  hosted_zone = (
    length(regexall(".glb", confluent_kafka_cluster.dedicated-pl.bootstrap_endpoint)) > 0 ?
    ## Removes the glb.* prefix if from the ccloud endpoint if present
    replace(regex(
      "^[^.]+-([0-9a-zA-Z]+[.].*):[0-9]+$",
      confluent_kafka_cluster.dedicated-pl.rest_endpoint
      )[0],
    "glb.", "") :
    regex(
      "[.]([0-9a-zA-Z]+[.].*):[0-9]+$",
      confluent_kafka_cluster.dedicated-pl.bootstrap_endpoint
    )[0]
  )
  network_id = regex("^([^.]+)[.].*", local.hosted_zone)[0]
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group
}

data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_subnet" "subnet" {
  for_each = var.subnet_name_by_zone

  name                 = each.value
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_resource_group.rg.name
}


# The DNS hosted zone for creating the DNS records to confluent cloud
resource "azurerm_private_dns_zone" "hz" {
  resource_group_name = data.azurerm_resource_group.rg.name
  name                = local.hosted_zone
}

resource "azurerm_private_endpoint" "endpoint" {
  for_each = var.subnet_name_by_zone

  name                = "confluent-${local.network_id}-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group
  subnet_id           = data.azurerm_subnet.subnet[each.key].id

  private_service_connection {
    name                 = "confluent-${local.network_id}-${each.key}"
    is_manual_connection = true
    request_message      = "PL"
    private_connection_resource_alias = lookup(
      confluent_network.pl-network.azure[0].private_link_service_aliases,
      each.key,
      "\n\nerror: ${each.key} subnet is missing from CCN's Private Link service aliases"
    )
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "hz-vnet-link" {
  name                  = data.azurerm_virtual_network.vnet.name
  resource_group_name   = data.azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.hz.name
  virtual_network_id    = data.azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_a_record" "bootstrap-dns-record" {
  name                = "*"
  zone_name           = azurerm_private_dns_zone.hz.name
  resource_group_name = data.azurerm_resource_group.rg.name
  ttl                 = 60
  records = [
    for _, ep in azurerm_private_endpoint.endpoint : ep.private_service_connection[0].private_ip_address
  ]
}

resource "azurerm_private_dns_a_record" "zonal-dns-record" {
  for_each = var.subnet_name_by_zone

  name                = "*.az${each.key}"
  zone_name           = azurerm_private_dns_zone.hz.name
  resource_group_name = data.azurerm_resource_group.rg.name
  ttl                 = 60
  records = [
    azurerm_private_endpoint.endpoint[each.key].private_service_connection[0].private_ip_address,
  ]
}
