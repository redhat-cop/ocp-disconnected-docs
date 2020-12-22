
# Installing OpenShift in Disconnected Microsoft Azure Government using IPI


## Overview

This guide is intended to demonstrate how to perform the OpenShift installation using the IPI method on Microsoft Azure Government. In addition, the guide will walk through performing this installation on an existing disconnected network. In other words the network does not allow access to and from the internet.


## MAG Configuration Requirements

In this guide, we will install OpenShift onto an existing virtual network. This virtual network will contain two private subnets that are firewalled off from access to and from the internet. As we will need a way to gain access to those subnets, there is one subnet that will be the public subnet and that will host the bastion node from which we will use to access the private network. The following section entitled Example MAG configuration details the network configuration used in the guide. While the internet is firewalled off from the private network, we still need to allow access to the Azure and Azure Government cloud APIs. Without that we will not be able to install a cloud aware OpenShift cluster. Please note the firewall rules created that allow this access to the Azure cloud APIs.

This guide will assume that the user has valid accounts and subscriptions to both Red Hat OpenShift and MS Azure Government. This guide will also assume that an SSH keypair was created and the files azure-key.pem and azure-key.pub both exist.


### Example MAG Configuration

 The following section may be used to create a virtual network with the following components.



*   Service Principal Account
*   Azure Virtual Network
*   Private DNS zone
*   Firewall
*   Public and Private subnets
*   Bastion Host
*   Registry Host

Obtain Azure CLI and login

Use the link below and follow the instructions to install the Azure CLI



*   [https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-yum?view=azure-cli-latest](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-yum?view=azure-cli-latest)

Login to azure and set the cloud provider


```
az login

az cloud set --name AzureUSGovernment 
```


Create Service Principal account

Use the link below and follow the instructions to create the Service Principal account. Make note of the subscription id, tenant id, client id and password token, these will be used later in this guide.



*   [https://docs.openshift.com/container-platform/4.6/installing/installing_azure/installing-azure-account.html#installation-azure-service-principal_installing-azure-account](https://docs.openshift.com/container-platform/4.6/installing/installing_azure/installing-azure-account.html#installation-azure-service-principal_installing-azure-account)

Create Resource Group

Create a resource group where AZURE_REGION is either usgovtexas or usgovvirginia


```
az group create -l <AZURE_REGION> -n <RESOURCE_GROUP>
```


Create VNET


```
az network vnet create -g <RESOURCE_GROUP> -n <VNET_NAME> --address-prefixes 10.1.0.0/16
```


Create FW Rules and Route table for Private Subnets

The Firewall will block traffic to and from the internet. In order for the OpenShift cluster to be cloud aware and to be able to run the IPI method of install, we need to allow access to the Azure and Azure for Government APIs.


```
az extension add -n azure-firewall

az network firewall create -g <RESOURCE_GROUP> -n <FW>

az network vnet subnet create \
  -g <RESOURCE_GROUP> \
  --vnet-name <VNET_NAME> \
  -n AzureFirewallSubnet \
  --address-prefixes 10.1.10.0/24

az network public-ip create \
  --name fw-pip \
  --resource-group <RESOURCE_GROUP> \
  --allocation-method static \
  --sku standard

az network firewall ip-config create \
  --firewall-name <FW> \
  --name FW-config \
  --public-ip-address fw-pip \
  --resource-group <RESOURCE_GROUP> \
  --vnet-name <VNET_NAME>

fwprivaddr=$( \
  az network firewall ip-config list \
  -g <RESOURCE_GROUP> \
  -f <FW> \
  --query "[?name=='FW-config'].privateIpAddress" \
  --output tsv)

az network route-table create \
  --name Firewall-rt-table \
  --resource-group <RESOURCE_GROUP> \
  --disable-bgp-route-propagation true

az network firewall application-rule create \
  --collection-name azure_gov \
  --firewall-name <FW> \
  --name azure \
  --protocols Http=80 Https=443 \
  --resource-group <RESOURCE_GROUP> \
  --target-fqdns \
    *microsoftonline.us \
    *graph.windows.net \
    *usgovcloudapi.net \
    *applicationinsights.us \
    *microsoft.us \
  --source-addresses 10.1.1.0/24 10.1.2.0/24 \
  --priority 100 \
  --action Allow

az network firewall application-rule create \
  --collection-name azure_ms \
  --firewall-name <FW> \
  --name azure \
  --protocols Http=80 Https=443 \
  --resource-group <RESOURCE_GROUP> \
  --target-fqdns \
    *azure.com *microsoft.com \
    *microsoftonline.com \
    *windows.net \
  --source-addresses 10.1.1.0/24 10.1.2.0/24 \
  --priority 200 \
  --action Allow
```


Create Public Subnet


```
az network vnet subnet create \
  -g <RESOURCE_GROUP> \
  --vnet-name <VNET_NAME> \
  -n <PUBLIC_SUBNET> \
  --address-prefixes 10.1.0.0/24
```


Create Private Subnet for Control Plane


```
az network vnet subnet create  \
  -g <RESOURCE_GROUP> \
  --vnet-name <VNET_NAME> \
  -n <CONTROL_SUBNET> \
  --address-prefixes 10.1.1.0/24 \
  --route-table Firewall-rt-table
```


Create Private Subnet for Compute Plane


```
az network vnet subnet create \
  -g <RESOURCE_GROUP> \
  --vnet-name <VNET_NAME> \
  -n <COMPUTE_SUBNET> \
  --address-prefixes 10.1.2.0/24 \
  --route-table Firewall-rt-table
```


Create Bastion host in Public Subnet

Note: Ensure that the file azure-key.pub exists in the current working directory. Also, if the operator catalog will also be downloaded copied over, please adjust the os-disk-size-gb value accordingly.


```
az vm create -n <BASTION> -g <RESOURCE_GROUP> \
  --image RedHat:RHEL:8.2:latest \
  --size Standard_D2s_v3 \
  --os-disk-size-gb 150 \
  --public-ip-address bastion-pub-ip \
  --vnet-name <VNET_NAME> --subnet <PUBLIC_SUBNET> \
  --admin-username azureuser \
  --ssh-key-values azure-key.pub
```


Create Registry Host in Private Subnet

Note: Ensure that the file azure-key.pub exists in the current working directory. Also, if the operator catalog will also be downloaded copied over, please adjust the os-disk-size-gb value accordingly.


```
az vm create -n <REGISTRY> -g <RESOURCE_GROUP> \
  --image RedHat:RHEL:8.2:latest \
  --size Standard_D2s_v3 \
  --os-disk-size-gb 150 \
  --public-ip-address '' \
  --vnet-name <VNET_NAME> --subnet <CONTROL_SUBNET> \
  --admin-username azureuser \
  --ssh-key-values azure-key.pub
```


Create Private DNS and add A Record for Registry host

The REGISTRY_IP is the private ip address assigned to the Registry host in the previous step.


```
az network private-dns zone create -g  <RESOURCE_GROUP> -n <DOMAIN>

az network private-dns link vnet create \
  -g <RESOURCE_GROUP> -n private-dnslink \
  -z <DOMAIN> -v <VNET_NAME> -e true

az network private-dns record-set a add-record \
  -g <RESOURCE_GROUP> \
  -z <DOMAIN> \
  -n registry \
  -a <REGISTRY_IP>
```


Resize Logical Volume on Bastion


```
scp -i azure-key.pem azure-key.pem azureuser@${BASTION_PUBLIC_IP}:~/.ssh/azure-key.pem

ssh  -i azure-sshkey.pem azureuser@${BASTION_PUBLIC_IP}

sudo lsblk #identify blk dev where home is mapped to (ex /dev/sda2)
sudo parted -l #when prompted type 'fix'
sudo growpart /dev/sda 2
sudo pvresize /dev/sda2
sudo pvscan
sudo lvresize -r -L +125G /dev/mapper/rootvg-homelv
```


Resize Logical Volume on Registry


```
#From bastion
ssh -i ~/.ssh azure-sshkey.pem azureuser@registry.<DOMAIN>

sudo lsblk # identify blk dev where home is mapped to (ex /dev/sda2)
sudo parted -l #when prompted type 'fix'
sudo growpart /dev/sda 2
sudo pvresize /dev/sda2
sudo pvscan
sudo lvresize -r -L +125G /dev/mapper/rootvg-homelv
```



## OpenShift Deployment

### YouTube Video

Here is a video that follows the directions in the next section

https://youtu.be/JcoTBcm3cIc

### Directions

Create Bundle on Bastion

In order to capture all the artifacts needed to install openshift, this guide will use a tool called openshift4_mirror. Please see [https://github.com/RedHatGov/openshift4-mirror](https://github.com/RedHatGov/openshift4-mirror) for more information about this tool. In addition, the pull-secret will need to be obtained from [https://cloud.redhat.com/openshift/install/pull-secret](https://cloud.redhat.com/openshift/install/pull-secret).  If the operator catalogs are also needed, ensure that there is enough disk space and remove the --skip-catalogs flag.


```
#From Bastion
sudo dnf install podman

mkdir mirror && cd mirror

podman run -it -v ./:/app/bundle:Z quay.io/redhatgov/openshift4_mirror:latest

./openshift_mirror bundle \
 	--openshift-version 4.6.3 \
 	--platform azure \
 	--skip-existing --skip-catalogs \
	--pull-secret '<PULL_SECRET>'

#exit by using ctrl-d

tar czf OpenShiftBundle-4.6.3.tgz 4.6.3/

```


Push Bundle to Registry


```
#From Bastion
scp -i ~/.ssh/azure-key.pem OpenShiftBundle-4.6.3.tgz registry.<DOMAIN>:~

ssh -i ~/.ssh/azure-key.pem registry.<DOMAIN>:~
```


Start Image Registry


```
#From Registry

tar xzf OpenShiftBundle-4.6.3.tgz

cd 4.6.3

openssl req -newkey rsa:4096 -nodes -sha256 -keyout domain.key -x509 -days 365 -out domain.crt -subj "/CN=registry.<DOMAIN>/O=Red Hat/L=Default City/ST=TX/C=US"

sudo firewall-cmd --zone=public --permanent --add-port=5000/tcp
sudo firewall-cmd --reload

bin/oc image serve --dir=$PWD/release/ --tls-crt=domain.crt --tls-key=domain.key

#Test from Bastion
curl -k https://registry.<DOMAIN>:5000/v2/openshift/
```


Prep install-config.yaml


```
#From Registry

cd && mkdir ocp_install && cd ocp_install

vi install-config.yaml # copy and paste install-config.template from below

#Edit template as needed
```


install-config.template


```
apiVersion: v1
baseDomain: <DOMAIN>
compute:
- hyperthreading: Enabled
  name: worker
  platform:
	azure:
  	osDisk:
    	diskSizeGB: 512
  	type: Standard_D2s_v3
  replicas: 4
controlPlane:
  hyperthreading: Enabled
  name: master
  platform:
	azure:
  	osDisk:
    	diskSizeGB: 512
	type: Standard_D8s_v3
  replicas: 3
metadata:
  creationTimestamp: null
  name: <CLUSTER_NAME>
networking:
  clusterNetwork:
  - cidr: 10.11.0.0/16
	hostPrefix: 23
  machineNetwork:
  - cidr: 10.1.1.0/24
  - cidr: 10.1.2.0/24
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
platform:
  azure:
	baseDomainResourceGroupName: <RESOURCE_GROUP>
	cloudName: AzureUSGovernmentCloud
	computeSubnet: <COMPUTE_SUBNET>
	controlPlaneSubnet: <CONTROL_SUBNET>
	networkResourceGroupName: <RESOURCE_GROUP>
	outboundType: UserDefinedRouting
	region: <AZURE_REGION>
	virtualNetwork: <VNET_NAME>
publish: Internal
pullSecret: |
  { "auths": { "<REGISTRY_DNS>": { "auth": "", "email": "example@redhat.com" } } }
additionalTrustBundle: |
  -----BEGIN CERTIFICATE-----
  MIIFozCCA4ugAwIBAgIUKcifYaM+d4mCC6RNgnKUpFFARfswDQYJKoZIhvcNAQEL
  ...
  -----END CERTIFICATE-----
imageContentSources:
- mirrors:
  - <REGISTRY_DNS>:5000/openshift/release
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - <REGISTRY_DNS>:5000/openshift/release
  source: registry.svc.ci.openshift.org/ocp/release
- mirrors:
  - <REGISTRY_DNS>:5000/openshift/release
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
sshKey: |
	ssh-rsa AAAAB3Nza...
```


Run OpenShift Install

The first time the install is run, it will prompt for the azure subscription id, tenant id, client id, and client secret/password.  These values will need to correspond to the service principal account required for the installation.  It will then save this to $HOME/.azure/osServicePrincipal.json and will reference that file for future runs.


```
#From Bastion

cd ~/4.6.3

bin/openshift-install create cluster --dir=/home/azureuser/ocp_install/ --log-level=debug
```


Once the installation completes successfully, the logs will print out the URL to the OpenShift console along with the password for the kubeadmin account. Please note that you will need to establish a VPN connection, or some like method in order to be able to access the web console. Additionally, It will print the path to the kubeconfig file that may be used with the OpenShift CLI (oc) to connect to the OpenShift API service. The following is an example of the logs.


```
INFO Install complete!                       	 
INFO To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/home/azureuser/ocp_install/auth/kubeconfig'
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.openshift.example.com
INFO Login to the console with user: "kubeadmin", and password: "XXXXX-XXXXX-XXXXX-XXXXX"
DEBUG Time elapsed per stage:                 	 
DEBUG 	Infrastructure: 13m57s              	 
DEBUG Bootstrap Complete: 9m25s               	 
DEBUG  Bootstrap Destroy: 5m57s               	 
DEBUG  Cluster Operators: 12m39s              	 
INFO Time elapsed: 42m7s
```



