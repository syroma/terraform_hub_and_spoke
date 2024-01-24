# Resource Group
resource "azurerm_resource_group" "hubspoke_rg" {
  name     = "hubspoke-rg"
  location = "East US"
}

data "azurerm_subscription" "current" {
}

resource "azurerm_network_manager" "hubspoke_net_manager" {
  name                = "example-network-manager"
  location            = azurerm_resource_group.hubspoke_rg.location
  resource_group_name = azurerm_resource_group.hubspoke_rg.name
  scope {
    subscription_ids = [data.azurerm_subscription.current.id]
  }
  scope_accesses = ["Connectivity", "SecurityAdmin"]
  description    = "hubspoke network manager"
}

resource "azurerm_network_manager_network_group" "TwoNetworks" {
  name               = "twonetworks"
  network_manager_id = azurerm_network_manager.hubspoke_net_manager.id
}

# Virtual Network for Hub--------------------------------------------------------
resource "azurerm_virtual_network" "hub_vnetwork_A" {
  name                = "hub-vnetwork-A"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.hubspoke_rg.location
  resource_group_name = azurerm_resource_group.hubspoke_rg.name
}

# Subnets for Hub
resource "azurerm_subnet" "hub_subnet_A" {
  name                 = "hub-subnet-A"
  resource_group_name  = azurerm_resource_group.hubspoke_rg.name
  virtual_network_name = azurerm_virtual_network.hub_vnetwork_A.name
  address_prefixes     = ["10.0.0.0/24"]
}

# Virtual Network for Spoke B----------------------------------------------------
resource "azurerm_virtual_network" "spoke_vnetwork_B" {
  name                = "spoke-vnetwork-B"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.hubspoke_rg.location
  resource_group_name = azurerm_resource_group.hubspoke_rg.name
}

resource "azurerm_subnet" "hub_subnet_B" {
  name                 = "hub-subnet-B"
  resource_group_name  = azurerm_resource_group.hubspoke_rg.name
  virtual_network_name = azurerm_virtual_network.spoke_vnetwork_B.name
  address_prefixes     = ["10.1.0.0/24"]
}

# Virtual Network for Spoke C----------------------------------------------------
resource "azurerm_virtual_network" "spoke_vnetwork_C" {
  name                = "spoke-vnetwork-C"
  address_space       = ["10.2.0.0/16"]
  location            = azurerm_resource_group.hubspoke_rg.location
  resource_group_name = azurerm_resource_group.hubspoke_rg.name
}

resource "azurerm_subnet" "hub_subnet_C" {
  name                 = "hub-subnet-C"
  resource_group_name  = azurerm_resource_group.hubspoke_rg.name
  virtual_network_name = azurerm_virtual_network.spoke_vnetwork_C.name
  address_prefixes     = ["10.2.0.0/24"]
}


resource "azurerm_public_ip" "vnetA_gatewayIP" {
  name                = "pub-ip"
  location            = azurerm_resource_group.hubspoke_rg.location
  resource_group_name = azurerm_resource_group.hubspoke_rg.name

  allocation_method = "Dynamic"
}

resource "azurerm_subnet" "vnet_A_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hubspoke_rg.name
  virtual_network_name = azurerm_virtual_network.hub_vnetwork_A.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Virtual Network Gateway for Site-to-Site VPN
resource "azurerm_virtual_network_gateway" "vpn_gateway" {
  name                = "vpn-gateway"
  location            = azurerm_resource_group.hubspoke_rg.location
  resource_group_name = azurerm_resource_group.hubspoke_rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = "VpnGw1"

  ip_configuration {
    name                          = "vnetGateway-Config"
    public_ip_address_id          = azurerm_public_ip.vnetA_gatewayIP.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.vnet_A_gateway.id
  }
}

resource "azurerm_network_manager_connectivity_configuration" "hubspokemodel" {
  name                  = "example-connectivity-conf"
  network_manager_id    = azurerm_network_manager.hubspoke_net_manager.id
  connectivity_topology = "HubAndSpoke"
  applies_to_group {
    group_connectivity = "DirectlyConnected"
    network_group_id   = azurerm_network_manager_network_group.TwoNetworks.id
  }

  # applies_to_group {
  #   group_connectivity = "DirectlyConnected"
  #   network_group_id   = azurerm_network_manager_network_group.example2.id
  # }

  hub {
    resource_id   = azurerm_virtual_network.hub_vnetwork_A.id
    resource_type = "Microsoft.Network/virtualNetworks"
  }
}

# # Subnet for DMZ (Web Servers)
# resource "azurerm_subnet" "dmz_subnet" {
#   name                 = "dmz-subnet"
#   resource_group_name  = azurerm_resource_group.hubspoke_rg.name
#   virtual_network_name = azurerm_virtual_network.spoke_net.name
#   address_prefixes     = ["10.1.1.0/24"]
# }

# # Subnet for Internal (SQL Servers)
# resource "azurerm_subnet" "internal_subnet" {
#   name                 = "internal-subnet"
#   resource_group_name  = azurerm_resource_group.hubspoke_rg.name
#   virtual_network_name = azurerm_virtual_network.spoke_net.name
#   address_prefixes     = ["10.1.2.0/24"]
# }





# # Local Network Gateway for Site-to-Site VPN (Simulated)
# resource "azurerm_local_network_gateway" "local_network_gateway" {
#   name                = "local-network-gateway"
#   location            = azurerm_resource_group.hubspoke_rg.location
#   resource_group_name = azurerm_resource_group.hubspoke_rg.name
#   gateway_address     = "192.168.1.1"      # Simulated IP for the on-premises VPN gateway
#   address_space       = ["192.168.1.0/24"] # Simulated on-premises network CIDR
# }

# # Connection between Virtual Network Gateway and Local Network Gateway
# resource "azurerm_virtual_network_gateway_connection" "vpn_connection" {
#   name                = "vpn-connection"
#   location            = azurerm_resource_group.hubspoke_rg.location
#   resource_group_name = azurerm_resource_group.hubspoke_rg.name

#   type                       = "IPsec"
#   virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn_gateway.id
#   local_network_gateway_id   = azurerm_local_network_gateway.local_network_gateway.id

#   shared_key = "YourSharedKey"
# }

# # Connecting Hub and Spoke using VPN
# resource "azurerm_virtual_network_peering" "hub_to_spoke_peering" {
#   name                      = "hub-to-spoke"
#   resource_group_name       = azurerm_resource_group.hubspoke_rg.name
#   virtual_network_name      = azurerm_virtual_network.hub_net.name
#   remote_virtual_network_id = azurerm_virtual_network.spoke_net.id
#   allow_forwarded_traffic   = true
#   allow_gateway_transit     = true
#   use_remote_gateways       = false
# }

# resource "azurerm_virtual_network_peering" "spoke_to_hub_peering" {
#   name                      = "spoke-to-hub"
#   resource_group_name       = azurerm_resource_group.hubspoke_rg.name
#   virtual_network_name      = azurerm_virtual_network.spoke_net.name
#   remote_virtual_network_id = azurerm_virtual_network.hub_net.id
#   allow_forwarded_traffic   = true
#   allow_gateway_transit     = true
#   use_remote_gateways       = true
# }
