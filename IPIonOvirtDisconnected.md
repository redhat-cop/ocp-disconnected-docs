RHV/OVirt disconnected IPI installations
========================================

This guide covers how to install OCP 4.8+ on Red Hat RHV (OVirt) in a disconnected environments.

Definitions:
------------

-	Disconnected
	-	An environment that is prevented from accessing the public internet where OCP container images and executable are located.
	-	The general process of getting software to a disconnected environment involves a physical media with data being brought to the isolated network.
	-	There is no temporary switch to allow access to the internet (airgabed)
-	Bastion host
	-	A VM/host where installation is managed from. A bastion host exists within the disconnected network and as a temporary system on a connected platform.
-	Network Services
	-	DNS - Domain Name Service. This service translates names to IPs are are required for an OCP install
	-	NTP - Network Time Protocol. This service allows multiple hosts to synchronize their clocks required for proper cluster functionality. This is required for an OCP install.
	-	DHCP - Dynamic Host Configuration Protocol. This service provides BOOTP ethernet features resulting in automatic assignment of IP addresses for hosts. This is required for OCP installs using the IPI method.
-	IPI
	-	Installer Provision Infrastructure. The openshift installer creates the underlying infrastructure (VMs) that OpenShift is running on.
-	UPI
	-	User Provisioned Infrastructure. The installer does not create/manage the infrastructure, but needs to be "guided" and told where pre-configured infrastructure is located.
- Host
  + For this guide, a host is a VM running in RHV/oVirt. For bastions this could be a host running bare metal or on a different infrastructure. This guide will use "host" to describe a VM used for OpenShift.

# Prerequisites

This guide assumes an already installed and working version of RHV 4.4. The installation guide can be found here: https://access.redhat.com/documentation/en-us/red_hat_virtualization/4.4/html/product_guide/installation

Minimal configuration:
* 3 RHVH nodes with 16 cores, 128GB of memory each. 32 cores is recommended if ODF is needed as part of the installation.
* 10GBps switches for the RHVH nodes and attached infrastructure:
  - Storage server - Gluster or CEPH backend storage for RHVH
    - At least 1TB of total redundant storage (RAID 5, 6, 10 etc)
  - Separate storage network on nodes. For production use, each RHV node should have dual nics/fiber for each interface:
    - *oVirtMgmt*: Front-end IP for management. This can be kept on 1MBps and not 10gbps. This maps to the IP address of the RHVH node.
    - *OcpNetwork*: VM network for OCP installation. This must be on the 10gpbs network.
    - *StorageNetwork*: Network between RHVH nodes and storage nodes. Must be on 10GBps. Each RHVH node must have an IP in the storage network (can be on a separate VLAN).
* RHV Manager - this can be self-hosted or on a separate physical server. See installation guide and installation options to see what will work for the environment. This system should be 8GB of RAM and at least 2 cores. Highly recommend using a valid certificate and not self-signed certs for the API.
* DNS, Ceritificate management and DHCP services exists on subnet selected for OCP install. Suggest using FreeIPA and add DHCP to this server. This is an easy two small VMs on RHV (FreeIPA should always be more than a single server with replication).
  + TODO: Add section on configuring FreeIPA/DHCP
* RHV service account for OCP installation.  RHV can be configured to use Kerberos from FreeIPA for authentication - not required but "it helps". Create separate account with rights to create/destroy VMs and Virtual disk images (not admin!). This account will be used when configuring the openshift installer for RHV.

# RHV configuration

TODO .. add setup of networks, storage and users

# Online Bastion Configuration

Note - this bastion host must be connected to the internet. It's used to retrieve all software needed for the installation and make an export to take to the offline cluster.

## Install the OC CLI
On a RHEL8, use a non-root account and execute the following content:

``` bash
mkdir $HOME/{bin,Downloads} 2>/dev/null

cat <<EOF > $HOME/bin/env.sh
export ocp4url="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest"
export bin=$HOME/bin"
export ocptar="openshift-client-linux.tar.gz"
export ocpinstall="openshift-install-linux.tar.gz"
EOF

chmod +x $HOME/bin/env.sh

source $HOME/bin/env.sh

for item in $ocptar $ocpinstall; do
  curl -o $HOME/Downloads/$item ${ocp4url}/${item}
done

tar -pxv -C $HOME/bin -f $HOME/Downloads/${ocptar}
tar -pxv -C $HOME/bin -f $HOME/Downloads/${ocpinstall}

rm $HOME/bin/README*

# This should return the version of oc if all worked
oc version
```

Save the file

* The OC CLI
* A [disconnected registry](appendix/disconnected-registry-standalone-quay.md). Any registry can be used; this guide assumes QUAY.
