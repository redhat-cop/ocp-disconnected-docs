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

This guide assumes an already installed and working version of RHV 4.6. The installation guide can be found here: https://access.redhat.com/documentation/en-us/red_hat_virtualization/4.4/html/product_guide/installation

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

Note - this bastion host must be connected to the internet. It's used to retrieve all software needed for the installation and make an export to take to the offline cluster. This host should/will not have access to the network where OCP eventually will be installed.

## Install the OC CLI
On a RHEL8, use a non-root account and execute the following content:

```bash
mkdir $HOME/{bin,Downloads} 2>/dev/null

ocp4url="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest"
bin=$HOME/bin"
ocptar="openshift-client-linux.tar.gz"
ocpinstall="openshift-install-linux.tar.gz"
rhcos="rhcos-openstack.x86_64.qcow2.gz"

for item in $ocptar $ocpinstall $rhcos; do
  curl -o "$HOME/Downloads/$item" "${ocp4url}/${item}"
done

tar -pxv -C $bin -f "$HOME/Downloads/${ocptar}"
tar -pxv -C $bin -f "$HOME/Downloads/${ocpinstall}"

rm $HOME/bin/README*

# This should return the version of oc if all worked
oc version
```

## Copy and make ready for export all container imageContentSources

The RHEL8 host must have podman installed.

A [disconnected registry](appendix/disconnected-registry-standalone-quay.md) must be installed. Any registry can be used; this guide assumes QUAY.

The resulting files should be copied to $HOME/Downloads

## Copy all files to offline media

The above steps results in several files, including openshift-${OCP_RELEASE}-release-bundle.tar.gz that needs to be copied to the $HOME/Downloads directory. From there, a simple copy to a USB or use *genisoimage* to create ISO that can be copied to DVDs. Note, these images will be sizable - standard music ISOs will not be large enough. Depending on the security requirements on the disconnected site, find the media that makes most sense. Note, there's a good chance what-ever media is picked will NOT be allowed to return, so be careful using something that you cannot loose.

The following files will exist:
*  openshift-client-linux.tar.gz
*	 openshift-install-linux.tar.gz
*  rhcos-openstack.x86_64.qcow2.gz (large)
*  openshift-${OCP_RELEASE}-release-bundle.tar.gz (very large)
*  postgres.tar
*  redis.tar
*  quay.tar

In addition, bring a RHEL 8 (everthing) ISO if the site doesn't have Satellite or other sources for RHEL.

# Offline Bastion Setup

Assumption: RHV 4.6 already installed, configured

Goal: Install a RHEL host where installation and maintenance will be done from. This host will be used to validate environment and hold configuration settings, management keys etc. The host will also be able to SSH into any OCP node for diagnostics - this access can be blocked by firewalls for any other host. When not in use, this host should be shutdown but NOT removed.

Log into the RHVM cluster as a cluster admin - admin rights to the oVirt cluster meant for OCP is a minimum. Check the following exists:

* Cluster defined with at least 3 hosts - note the cluster ID of this cluster (ie ccc53763-c479-410f-af0b-ec846929b46h). This is the Cluster ID and will be needed in the next section.
	+ Cluster must have 3 hosts, each at least 16 cores and 128GB of RAM. Recommend 32+ cores per host.
	+ Ensure a logical network for OCP is defined - ie. "aServerNetwork". This network must be assigned to NICs on each host that are on a 10 Gbps switch. 2 bonded nics is recommended but not required.
	+ Ensure compatability version is set to 4.6 for the cluster.
	+ Cluster should have a storage network defined to separate it from the VM traffic
	+ Note the Network ID of the "aServerNetwork" network for OCP (ie 5efa608a-2e5c-482c-a510-2e8adbef939f) - this is the Network ID needed for the install-config later in this guide.




# OpenShift Installation from Offline Bastion
