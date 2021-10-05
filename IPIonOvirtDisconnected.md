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

## Confirm RHV installation

Log into the RHVM cluster as a cluster admin - admin rights to the oVirt cluster meant for OCP is a minimum. Check the following exists:

* Cluster defined with at least 3 hosts - note the cluster ID of this cluster (ie ccc53763-c479-410f-af0b-ec846929b46h). This is the Cluster ID and will be needed in the next section.
	+ Cluster must have 3 hosts, each at least 16 cores and 128GB of RAM. Recommend 32+ cores per host.
	+ Ensure a logical network for OCP is defined - ie. "aServerNetwork". This network must be assigned to NICs on each host that are on a 10 Gbps switch. 2 bonded nics is recommended but not required.
	+ Ensure compatability version is set to 4.6 for the cluster.
	+ Cluster should have a storage network defined to separate it from the VM traffic
* Network Definition - "aServerNetwork" in this example
	+ Take note of the vnicProfileID of the "aServerNetwork" network for OCP (ie 1bf648af-a1f6-4c13-8fd7-636a11b2fd36) - this is the Network ID needed for the install-config later in this guide.
* Storage definition
	+ The installer will use a single storage domain for the VMs during creation, and create a Storage Class pointing to this storage domain for registry storage, etcd etc. Post installation you may want to add additional storage classes, where some could point to additional storage domains in oVirt, but for the installation we can only select one.
	+ Storage network must be high IO - spinning disks are not supported/recommended. SSDs at a minimum. NVMe is recommended.

If you cannot find the id for the vnicProfileID in the web-console, the following ansible will return the ID (from the Bastion host that will be created in the next step - the IDs are not created until the install-config is to be created)

ovirt-network.yaml:
```ansible
---
- name: Retrieve vNIC ID
  hosts: localhost
  connection: local
  gather_facts: yes
  vars:
    network: "aServerNetwork"

  tasks:
  - block:
    - name: Obtain SSO token with using username/password credentials
      ovirt_auth:
        url: "https://rhvm44.example.com/ovirt-engine/api"
        username: "rhevadmin@example.com"
        ca_file: "{{ lookup('env','HOME') }}/ansible/data/ca.crt"
        password: "secretpassword"
 		- name: Get network info
      ovirt_network_info:
        auth: "{{ ovirt_auth }}"
	      pattern: "name={{ network }}"
		    fetch_nested: yes
	    register: netinfo
	  - debug:
	      var: netinfo
    always:
    - name: Always revoke the SSO token
      ovirt_auth:
        state: absent
        ovirt_auth: "{{ ovirt_auth }}"
```

In the result will be a list of vNicProfiles - typically there will just be one. This is the ID needed above.

To provide the ovirt module, issue the following command:

```bash
$ ansible-galaxy collection install redhat.rhv
```

If some of the above areas are not present, do not proceed until oVirt is configured with the proper settings.

* In the installation configuration you'll need the following values:
	- ovirt_cluster_id: ccc53763-c479-410f-af0b-ec846929b46h
	- ovirt_network_name: aServerNetwork
	- ovirt_storage_domain_id: 9008664c-f69c-4139-bc4f-266aacda6ebf
	- vnicProfileID: 1bf648af-a1f6-4c13-8fd7-636a11b2fd36

With the above confirmed and recorded, clarify what subnet the aServerNetwork is assigned. This depends on the external network the cluster is connected to and isn't part of oVirt.

## Install/upload RHEL ISO
Until we have a bastion host, we'll focus on the RHV Management console. Once the bastion host is running, everything can be scripted.

Because the bastion host needs very few resources, it's not recommended to do a bare-metal install, but instead create a small VM in the same network as where OpenShift will be installed.

If the RHV environment does not have a RHEL template, and PXE boots using a Satellite server in the disconnected environment isn't available, we'll need to start by uploading the RHEL ISO that was put on the media for the offline site in the steps above.

To upload ISO's there are two options:
1) In the RHV Management console, open the storage domain and click UPLOAD. Choose the ISO file and wait for it to be uploaded.
2) Add the ISO to the "iso" domain (no deprecated) - this is often a NFS share. Copying the ISO directly to this NFS share will make it available.

To create a template, we first create a blank VM using the ISO as the boot media.

![Create empty VM](/images/ovirtVmCreateImg1.png)

Be sure to allocate at least 400GB of disk space. If you intend to keep this VM around, making a data disk and mounting it as /home will be a better approach. Should you want to use this ISO to create other RHEL systems, use a smaller disk (20-50GB) and when you create the bastion from this template, expand the size to 400GB.

Optionally configure the ISO as part of the permanent VM metadata:

![VM Disk Options](/images/ovirtVmCreateImg2.png)

Use "Run Once" and start the VM with the ISO as an active boot device. Do a "Minimal Install" and enable containers.  When the VM boots, it will get an IP in the same network OCP will be in - this validates DHCP is working. If the bastion is to host a permanent container registry or be used as a SSH target from outside

With the system installed, attach the system to IPA which will allow logins using the centralized users  or define a local user "ocp". Adding "ocp" to the wheels group to allow for local sudo will help during diagnostics, but is not required.

Post installation tasks:

* Ensure podman and skopeo are installed
* Install ansible-engine 2.9
* Verify DNS resolution works.
* Verify access to the oVirt API end pointing

Once the basic infrastructure is validated, shutdown the VM and convert it to a oVirt template. Be very sure to select "sealed". Create a new VM from this template with the correct bastion name, and continue below.

* Generate SSH key for OCP install (ssh-keygen)

Copy data from media created offsite onto bastion host:
* Create $HOME/Downloads
* Copy all data from selected media to $HOME/Downloads
* Follow the disconnected registry guide and instantiate the 3 QUAY containers. Ensure hostname matches what-ever certificate was created or redo the certificate with the hostname for this bastion.
* If external access to the registry is required, add firewall rule to allow port 443 traffic into the cluster.
* If there's already a registry on site, use skopeo to copy all registry content from QUAY once it runs to the existing local registry. Once this copy is done, the quay containers can be shutdown.

# OpenShift Installation from Offline Bastion
At this point you have a bastion host in the disconnected environment with all the files needed to do an OpenShift installation.  To continue, we need the following information:

Hostname and IP of the following:
* API end-point
  + Verify a hostname exist using the 'host' command and take note of the IP:
	+ ```[ocp@bastion ovirt]$ host api.ovirt.ocp4.peterlarsen.org
api.ovirt.ocp4.peterlarsen.org has address 192.168.11.40```
  + Take note of the IP address. Do a 'host' command on the IP to verify reverse resolution works.
	+ If DNS resolution does not work, the local DNS server for the network must be modified before the installation can be continued.  Alternative, install FreeIPA-server on the bastion host with DNS and use it to hold DNS entries (this is not recommended for production).
* Wildcard end-point
	+ ```host bla.apps.ovirt.ocp4.peterlarsen.org
bla.apps.ovirt.ocp4.peterlarsen.org has address 192.168.11.41```
	+ Take note of the IP address

The IPI install uses a keepalive VIP for each of these features and does not utilize a load balancer. A load balancer like HAProxy or F5 can be added post installation.  

## Generate pull-secret
Create a directory "$HOME/mirror" where we'll place local data about the environment to manage accessing the mirror.

Create pull-secret file in $HOME/mirror by using access data from the container registry that was copied to in the above step, or the local QUAY instance.

Use "podman" to login to the registry:

```podman login --authfile=$HOME/mirror/pull-secret.json quay2.example.com --username=ocp+robot --password=secretpassword```

If you omit the password and username you'll be prompted for these values. Verify the generated pull-secret file is valid json:

```jq . < $HOME/mirror/pull-secret.json```

This file will start with the element "auths" and have a list of hostnames with auth and email. The email is used for audit purposes, so using one that's recongized is recommended.

## Install the oc and kubectl commands

Install the 'oc' and 'kubectl' commands:

```bash
mkdir $HOME/{bin,Downloads} 2>/dev/null

bin=$HOME/bin"
ocptar="openshift-client-linux.tar.gz"

tar -pxv -C $bin -f "$HOME/Downloads/${ocptar}"

rm $HOME/bin/README*

# This should return the version of oc if all worked
oc version
```
## Generate openshift-install

We need to generate the openshift-install command based on the ocp-release image. To help, create a file defining the following environment variables:

```bash
export OCP_RELEASE="4.8.$REL"
export LOCAL_REGISTRY='quay2.example.com'
export LOCAL_REPOSITORY='ocp/openshift48'
export LOCAL_SECRET_JSON="pull-secret.json"
```

Set $REL to the release number that was downloaded initially. Make the local registry have the hostname of the bastion (not localhost!!) or the registry server the images were copied to.

Run the following commands:
```bash
cd $HOME/mirror
oc adm release extract -a ${LOCAL_SECRET_JSON} --command=openshift-install "${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-x86_64"
mv openshift-install $HOME/bin/
```

To test the validity run:

```
$ openshift-install version
install48 4.8.12
built from commit 450e95767d89f809cb1afe5a142e9c824a269de8
release image quay2.example.com/ocp/openshift48@sha256:c3af995af7ee85e88c43c943e0a64c7066d90e77fafdabc7b22a095e4ea3c25a
```

Note the release image - this must be the address of the "disconnected" container registry where all the OCP images are located.

## Setup RHCOS ovirt template for install
When using IPI the default behavior is to download the RHCOS image from a public web-site - the image depends on the cluster setup. For oVirt we use the openstack image which includes cloud-init and other boot configuration settings needed for the installer to be successful.

```bash
$ ansible-galaxy install ovirt.image-template
```

TODO: Change setup to allow direct upload from local file. Potentially using "ovirt_disk" directory:

$HOME/mirror/ovirt-rhcos.yaml:
```ansible
---
- name: Create RHCOS Template
  hosts: localhost
  connection: local
  gather_facts: no
  vars_files:
    # Contains encrypted `engine_password` varibale using ansible-vault
    - passwords.yml

  vars:
    baseurl: "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/latest/latest"
    rhcos_name: "rhcos-openstack.x86_64.qcow2.gz"
    rhcos_url: "{{ baseurl }}/{{ rhcos_name }}"
    image_checksum: "sha256:{{ baseurl }}/sha256sum.txt"
    template: rhcos-template
    engine_fqdn: "rhvm44.example.com"
    engine_user: "rhevadmin@peterlarsen.org"
    engine_cafile: "{{ lookup('env','HOME') }}/ansible/data/ca.crt"
    qcow_url: "{{ rhcos_url }}"
    template_cluster: ocpcluster
    template_name: rhcos_template
    template_memory: 16GiB
    template_cpu: 4
    template_disk_size: 120GiB
    template_disk_interface: virtio
    template_disk_storage: rhevquick
    template_operating_system: rhel_rhcos
    template_nics:
      - name: nic1
        profile_name: iso
        interface: virtio
    template_seal: false

  roles:
    - ovirt.image-template
```
