# Installing OpenShift in vmWare Disconnected using IPI

### Overview
This guide is intended to demonstrate how to perform the OpenShift installation using the installer provisioned infrastructure (IPI) method on vmWare. Additionally, this guide will provide details on properly configuring vmWare for a successful deployment.

### Environment Overview
This vmware environment used is has the following components:
- vCenter 7.0
- vSphere 7.0
- vSAN 
- A single portgroup for Public network access
- A single portgroup for internal network access
- RHEL 8.2 Template 

### Prerequisites
- at least one internet facing machine
- dns server with zones and subdomains
- dns entries (A Records) for registry, api and wildcard apps `*.apps`
- dhcp service

### vmWare Role Permissions
[vmware permissions](https://docs.openshift.com/container-platform/4.6/installing/installing_vsphere/installing-vsphere-installer-provisioned-customizations.html#installation-vsphere-installer-infra-requirements_installing-vsphere-installer-provisioned-customizations)

1. Create a new role:
- Click on menu, then click administration
- Click on `Roles` under `Access Control`
- Click the `+` sign to create a new role
- Using the document above, assign the correct permissions to the role
- Assign the role a name and give it an optional description
- Click Finish

2. Create a user 
- Click menu, then click administration
- Click `Users and Groups` under `Single Sign On`
- Select the appropriate domain in the `Domain` drop-down
- Click `ADD USER` and complete the required fields

3. Assigning Role to user
- Click menu, then click administration
- Click the `+` sign to add a permission
- Enter the username previously created
- Assign the role previously created
- Click `Propogate to children`

### Preparing the mirror node

<p class="callout info"> A virtual machine is deployed from the RHEL8 template and is configured with both the public and internal portgroups.</p>

1. Download the quay pull secret from [cloud.redhat.com](https://cloud.redhat.com)

2. Download the OpenShift commadline utilities and OVA files
```
curl -LfO  https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.7/latest/rhcos-vmware.x86_64.ova
```
```
curl -LfO http://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest-4.7/openshift-client-linux.tar.gz
```
```
curl -LfO http://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest-4.7/openshift-install-linux.tar.gz
```
```
curl -LfO http://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest-4.7/opm-linux.tar.gz
```

3. Install the OpenShift client on the local machine
```
tar xvf ./openshift-client-linux.tar.gz -C /usr/local/bin
```

4. Create environment variables for mirroring the content:
```
#!/bin/bash
export GODEBUG=x509ignoreCN=0
export OCP_RELEASE=4.7.1
export PRODUCT_REPO='openshift-release-dev'
export LOCAL_SECRET_JSON=/root/installsecret.json
export RELEASE_NAME='ocp-release'
export ARCHITECTURE='x86_64'
export REMOVABLE_MEDIA_PATH=/root/data/
```

5. Source the environment file
```
source environment.sh
```

6. Run the `oc mirror` command to pull the operators and images:
```
oc adm release mirror -a ${LOCAL_SECRET_JSON} --to-dir=${REMOVABLE_MEDIA_PATH}/mirror quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-${ARCHITECTURE}
```

The command will complete and the path /root/data will be populated with the required images for installation.

7. Archive the working directory into a tarball and move the tarball to the internal machine
```
tar cvf mirror_bundle.tar /root/data \
openshift-client-linux.tar.gz \
openshift-install-linux.tar.gz \
opm-linux.tar.gz \
rhcos-vmware.x86_64.ova
<your_pull_secret>.json 
```

8. SCP the file (or use whatever transfer means available) to the disconnected node:
```
scp mirror_bundle.tar <ip_of_disconnected_node>:~
```

## Disconnected node:

<p class="callout info"> A virtual machine is deployed from the RHEL8 template and is configured with only the internal portgroups.</p>

1. Enable the ports for the registry and web server through the local firewall:
```
firewall-cmd --add-service=http --add-service=https --permanent
firewall-cmd --add-port=5000/tcp --permanent
firewall-cmd --reload
```

2. Register machine to Satellite or YUM service to install packages:
|Name|Purpose|Required Y/N|
|-----|-----|-----|
|httpd|WebServer to host ova file| yes (or use web alt. (nginx))|
|unzip|unzip vmware certs| yes|
|jq| view json in readable format | no (will make managing json much easier|

3. Install packages:
```
dnf install -y httpd jq unzip
```

4. Install the vcenter certificates
```
curl -k -LfO https://vcenter.fq.dn/certs/download.zip`
unzip download.zip
```

5. Add certs to trust store
```
cp /root/certs/lin/* /etc/pki/ca-trust/source/anchors/
```
```
update-ca-trust extract
```
Unpack the tarball 
```
tar xvf mirror_bundle.tar
```

6. Unpack the openshift client tarballs
```
tar xvf ./openshift-client-linux.tar.gz -C /usr/local/bin/
```
```
tar xvf ./openshift-install-linux.tar.gz -C /usr/local/bin/
```
```
tar xvf ./opm-linux.tar.gz -C /usr/local/bin
```

9. Start | Enable httpd service and copy ova to webroot
```
systemctl enable --now httpd

cp /root/rhcos-vmware.x86_64 /var/www/html

restorecon -FRvv /var/www/html
```

10. Create the SSL certificates
```
openssl req -newkey rsa:4096 -nodes -sha256 -keyout domain.key -x509 -days 365 -out domain.crt -subj "/CN=registry.<DOMAIN>/O=Red Hat/L=Default City/ST=TX/C=US"
```

11. Use `oc image serve` to host the bootstrap registry content
```
oc image serve --tls-crt=/root/domain.crt --tls-key=/root/domain.key --listen=':5000' --dir=/root/data/mirror &
```

12. Test to make sure it's working:
**Note:** From the disconnected utility node:
```
ss -plunt | grep 5000
```

Expected Output:
```
tcp   LISTEN 0      128                              0.0.0.0:5000       0.0.0.0:*                     users:(("conmon",pid=13764,fd=5))
```
Create an SSH Key pair
```
ssh-keygen
```

13. Create base64 encoded registry username password `(user: registry| password: registry)`
```
echo -n 'registry:registry' | base64
```

**Expected Result:** `cmVnaXN0cnk6cmVnaXN0cnk=`

14. Create the registry pull secret
**Note:** The following string gets added to the install-config.yaml
```
{"auths":{"internal_registry.fqdn:5000":{"auth":"cmVnaXN0cnk6cmVnaXN0cnk="}}}
```

15. Create a deployment directory and a cluster directory:
`mkdir /root/deployment /root/openshift`

**Note:** Once the installer ingests the install-config, it is no longer available.

16. Create the install-config.yaml
`vim /root/deployment/install-config.yaml`

```yaml
apiVersion: v1
baseDomain: "{{ openshift_base_domain }}"
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform:
    vsphere:
      cpus: 4
      coresPerSocket: 2
      memoryMB: 16384
      osDisk:
        diskSizeGB: 120
  replicas: 3
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  platform:
    vsphere:
      cpus: 4
      coresPerSocket: 2
      memoryMB: 16384
      osDisk:
        diskSizeGB: 120
  replicas: 3
metadata:
  name: "{{ openshift_cluster_name }}"
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: "{{ openshift_machine_network }}"
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
platform:
  vsphere:
    apiVIP: "{{ openshift_api_VIP }}"
    ingressVIP: "{{ openshift_ingress_apps_VIP }}"
    cluster: "{{ vcenter_cluster }}"
    datacenter: "{{ venter_datacenter }}"
    folder: "{{ vcenter_openshift_vm_folder }}"
    defaultDatastore: "{{ vcenter_datastore }}"
    network: "{{ vcenter_virtual_machine_network }}"
    password: "{{ vcenter_openshift_svc_account_password }}"
    username: "{{ vcenter_openshift_svc_account }}"
    vCenter: "{{ vcenter_fqdn}}"
    clusterOSImage: "{{ openshift_ova_http_path }}"
publish: External
fips: true
pullSecret: '**<Use Pull Secret string created previously>**'
imageContentSources:
- mirrors:
  - registry.redhat.local:5000/openshift/release
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - registry.redhat.local:5000/openshift/release
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
sshKey: |
  ssh-rsa AAAAB3NzaC1yc2EAAAADA{...ommitted }  #This is the SSH public key output
additionalTrustBundle: |
  -----BEGIN CERTIFICATE-----
  -----END CERTIFICATE-----
```

17. Copy the config to the openshift directory and run the deployment
```
cp /root/deployment/install-config.yaml /root/openshift

openshift-install create cluster --dir=/root/openshift --log-level=debug
```

### Monitor the cluster deployment:
```
tail -f /root/openshift/.openshift_install.log

export KUBECONFIG=/root/openshift/auth/kubeconfig

oc get co

oc get nodes

oc get machines -A 
```

### Destroying the cluster
```
openshift-install destroy cluster --dir=openshift --log-level=debug
```