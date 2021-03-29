# Installing Azure Red Hat OpenShift (ARO) in Disconnected Microsoft Azure

## Overview

This guide will demonstrate how to install an Azure Red Hat OpenShift (ARO) cluster on an existing disconnected network in Microsoft Azure.  The network will disallow inbound connections from the internet.  The network will restrict outbound connections to the internet, allowing only the following endpoints:

*  `*azure.com *microsoft.com`
*  `*microsoftonline.com`
*  `*windows.net`

Note that restricting outbound connections entirely violates the [Azure Red Hat OpenShift support policy](https://docs.microsoft.com/en-us/azure/openshift/support-policies-v4#cluster-configuration-requirements).

## Installation

#### Set variables

```bash
LOCATION=eastus
RESOURCEGROUP=aro-disconnected
CLUSTER=aro-disconnected
VNET_NAME=aro-disconnected-vnet
FIREWALL_NAME=aro-disconnected-firewall
```

#### Create resource group

```bash
az group create -l $LOCATION -n $RESOURCEGROUP
```

#### Create virtual network

```bash
az network vnet create \
--resource-group $RESOURCEGROUP \
--name $VNET_NAME \
--address-prefixes 10.0.0.0/16
```

#### Create empty subnet for masters nodes
```bash
az network vnet subnet create \
--resource-group $RESOURCEGROUP \
--vnet-name $VNET_NAME \
--name master-subnet \
--address-prefixes 10.0.0.0/24
```

#### Create empty subnet for worker nodes
```bash
az network vnet subnet create \
--resource-group $RESOURCEGROUP \
--vnet-name $VNET_NAME \
--name worker-subnet \
--address-prefixes 10.0.1.0/24
```

#### Disable subnet private endpoint policies
```bash
az network vnet subnet update \
--name master-subnet \
--resource-group $RESOURCEGROUP \
--vnet-name $VNET_NAME \
--disable-private-link-service-network-policies true
```

*Note*: This must be executed to allow Private Link connections to your cluster by Azure SREs

#### Create a firewall subnet
```bash
az network vnet subnet create -g $RESOURCEGROUP --vnet-name $VNET_NAME -n AzureFirewallSubnet --address-prefixes 10.1.10.0/26 --service-endpoints Microsoft.ContainerRegistry
```

#### Create a jump host subnet
```bash
az network vnet subnet create -g $RESOURCEGROUP --vnet-name $VNET_NAME -n JumpHostSubnet --address-prefixes 10.0.2.0/24
```

#### Create Azure Firewall

Create public IP
```bash
az network public-ip create --name fw-pip --resource-group $RESOURCEGROUP --allocation-method static --sku standard
```

Create firewall and IP config
```bash
az extension add -n azure-firewall
az network firewall create -g $RESOURCEGROUP -n $FIREWALL_NAME --location $LOCATION
az network firewall ip-config create --firewall-name $FIREWALL_NAME --name FW-config --public-ip-address fw-pip --resource-group $RESOURCEGROUP --vnet-name $VNET_NAME
```

Get reference to Azure Firewall private IP address
```bash
fwprivaddr=$(az network firewall ip-config list -g $RESOURCEGROUP -f $FIREWALL_NAME --query "[?name=='FW-config'].privateIpAddress" --output tsv)
```

#### Create routing table
```bash
az network route-table create --name $FIREWALL_NAME-rt-table --resource-group $RESOURCE_GROUP
```

#### Create firewall route
```bash
az network route-table route create \
  --resource-group $RESOURCEGROUP \
  --name $FIREWALL_NAME-rt-table-route \
  --route-table-name $FIREWALL_NAME-rt-table \
  --address-prefix 0.0.0.0/0 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address $fwprivaddr
```

#### Add outbound application rule
```bash
az network firewall application-rule create -g $RESOURCEGROUP -f $FIREWALL_NAME --collection-name azure_ms --name azure --protocols 'http=80' 'https=443' --target-fqdns *azure.com *microsoft.com *microsoftonline.com *windows.net --source-addresses 10.0.0.0/24 10.0.1.0/24 --priority 100 --action Allow
```

#### Route internal traffic to firewall on the master and worker subnets
```bash
az network vnet subnet update -g $RESOURCEGROUP --vnet-name vnet --name master-subnet --route-table $FIREWALL_NAME-rt-table
az network vnet subnet update -g $RESOURCEGROUP --vnet-name vnet --name worker-subnet --route-table $FIREWALL_NAME-rt-table
```

#### Create the ARO cluster in the disconnected network
```bash
az aro create \
  --resource-group $RESOURCEGROUP \
  --name aro-cluster \
  --vnet $VNET_NAME \
  --master-subnet master-subnet \
  --worker-subnet worker-subnet \
  --apiserver-visibility Private \
  --ingress-visibility Private
```

## Smoke Test

