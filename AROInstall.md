# Installing Azure Red Hat OpenShift (ARO) in Disconnected Microsoft Azure

## Overview

This guide will demonstrate how to install an Azure Red Hat OpenShift (ARO) cluster on an existing disconnected network in Microsoft Azure.  The network will disallow inbound connections from the internet.  The network will restrict outbound connections to the internet based on the reqired [official list provided by Microsoft](https://docs.microsoft.com/en-us/azure/openshift/howto-restrict-egress#minimum-required-fqdn--application-rules).

*Note*: Restricting outbound connections entirely violates the [Azure Red Hat OpenShift support policy](https://docs.microsoft.com/en-us/azure/openshift/support-policies-v4#cluster-configuration-requirements).

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
--address-prefixes 10.0.0.0/24 \
--service-endpoints Microsoft.ContainerRegistry
```

*Note*: This subnet accesses Microsoft's internal container registry over a [private endpoint](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-service-endpoints-overview).  The internal container registry is used for provisioning the cluster, and it is not accessible for general use.  See [networking](https://docs.microsoft.com/en-us/azure/openshift/concepts-networking) for more information.

#### Create empty subnet for worker nodes
```bash
az network vnet subnet create \
--resource-group $RESOURCEGROUP \
--vnet-name $VNET_NAME \
--name worker-subnet \
--address-prefixes 10.0.1.0/24 \
--service-endpoints Microsoft.ContainerRegistry
```

*Note*: This subnet accesses Microsoft's internal container registry over a [private endpoint](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-service-endpoints-overview).  The internal container registry is used for provisioning the cluster, and it is not accessible for general use.  See [networking](https://docs.microsoft.com/en-us/azure/openshift/concepts-networking) for more information.

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
az network vnet subnet create -g $RESOURCEGROUP --vnet-name $VNET_NAME -n AzureFirewallSubnet --address-prefixes 10.0.10.0/26
```

*Note*: The Azure Firewall subnet size should be /26, see the [FAQ](https://docs.microsoft.com/en-us/azure/firewall/firewall-faq#why-does-azure-firewall-need-a--26-subnet-size).

#### Create a public subnet for bastion host
```bash
az network vnet subnet create -g $RESOURCEGROUP --vnet-name $VNET_NAME -n public-subnet --address-prefixes 10.0.2.0/24
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

Set Azure Firewall private IP address
```bash
fwprivaddr=$(az network firewall ip-config list -g $RESOURCEGROUP -f $FIREWALL_NAME --query "[?name=='FW-config'].privateIpAddress" --output tsv)
```

#### Create routing table
```bash
az network route-table create --name $FIREWALL_NAME-rt-table --resource-group $RESOURCEGROUP
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
az network firewall application-rule create \
  -g $RESOURCEGROUP -f $FIREWALL_NAME \
  --collection-name azure_ms \
  --name azure \
  --protocols 'http=80' 'https=443' \
  --target-fqdns *.quay.io sso.redhat.com registry.redhat.io management.azure.com mirror.openshift.com api.openshift.com registry.access.redhat.com login.microsoftonline.com gcs.prod.monitoring.core.windows.net *.blob.core.windows.net *.servicebus.windows.net *.table.core.windows.net \
  --source-addresses 10.0.0.0/24 10.0.1.0/24 \
  --priority 100 --action Allow
```

#### Route internal traffic to firewall on the master and worker subnets
```bash
az network vnet subnet update -g $RESOURCEGROUP --vnet-name $VNET_NAME --name master-subnet --route-table $FIREWALL_NAME-rt-table
az network vnet subnet update -g $RESOURCEGROUP --vnet-name $VNET_NAME --name worker-subnet --route-table $FIREWALL_NAME-rt-table
```

#### Create the ARO cluster in the disconnected network
```bash
az aro create \
  --resource-group $RESOURCEGROUP \
  --name $CLUSTER \
  --vnet $VNET_NAME \
  --master-subnet master-subnet \
  --worker-subnet worker-subnet \
  --apiserver-visibility Private \
  --ingress-visibility Private
```

*Note*: Optionally add `--pull-secret` if you have a [Red Hat pull secret](https://docs.microsoft.com/en-us/azure/openshift/howto-add-update-pull-secret)

#### Create Bastion Host in public subnet

Create SSH key pair
```bash
ssh-keygen -m PEM -t rsa -b 4096 -f azure-key
```

Create VM
```bash
az vm create -n bastion -g $RESOURCEGROUP \
  --image RedHat:RHEL:8.2:latest \
  --size Standard_D2s_v3 \
  --public-ip-address bastion-pub-ip \
  --vnet-name $VNET_NAME --subnet public-subnet \
  --admin-username azureuser \
  --ssh-key-values azure-key.pub
```

## Smoke Test

#### Connect to ARO over public internet

Set kubeadmin password
```bash
KUBEADMIN_PASSWORD=$(az aro list-credentials --name $CLUSTER --resource-group $RESOURCEGROUP --query kubeadminPassword -o tsv)
```

Try logging in
```bash
API_SERVER=$(az aro show -g $RESOURCEGROUP -n $CLUSTER --query apiserverProfile.url -o tsv)
oc login $API_SERVER -u kubeadmin -p $KUBEADMIN_PASSWORD
```

The connection fails because the API server is not accessible to the public internet.


#### Connect to ARO through Bastion host

Make note of `API_SERVER` and `KUBEADMIN_PASSWORD`
```bash
echo $API_SERVER
echo $KUBEADMIN_PASSWORD
```

SSH to the Bastion host
```bash
BASTION_PUBLIC_IP=$(az vm show -d -g $RESOURCEGROUP -n bastion --query publicIps -o tsv)
ssh -i azure-key azureuser@$BASTION_PUBLIC_IP
```

Install `oc` on the Bastion host

*Note*: You can find the latest release of the CLI [here](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/)

```bash
$ wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
$ mkdir openshift
$ tar -zxvf openshift-client-linux.tar.gz -C openshift
$ echo 'export PATH=$PATH:~/openshift' >> ~/.bashrc && source ~/.bashrc
```

Login to the cluster

```bash
$ oc login <API_SERVER> -u kubeadmin -p <KUBEADMIN_PASSWORD>
$ oc whoami
```

> Output

```
kube:admin
```

#### Test outbound connection to public internet

*Note*: Make sure to connect to ARO through the Bastion host (see previous section)

Execute an outbound internet connection from a pod in the cluster

```bash
$ oc exec -it alertmanager-main-0 -n openshift-monitoring -- curl redhat.com
```

> Output (sample)

```
HTTP request from 10.20.1.6:42876 to redhat.com:80. Url: redhat.com. Action: Deny. No rule matched. Proceeding with default action
```

The connection is denied by the Azure Firewall.
