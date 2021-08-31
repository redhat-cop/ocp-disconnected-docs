
## Sparta


#### Red Hat OpenShift Platform Delivery as Code

Sparta was created to solve the problem of delivering the Red Hat OpenShift Container Platform, (based on Kubernetes) along with an extensible middleware and application portfolio, within restricted deployment environments (e.g. behind an air gap).

The delivery design centers around the Koffer and Konductor automation runtime containers as pluggable artifact collection and Infrastructure as Code (IaC) delivery engines, which orchestrates the CloudCtl deployment services pod to augment cloud native features.

#### What is CodeSparta?

In the simplest terms, CodeSparta is a target agnostic, additive, (Kubernetes) private cloud Trusted Platform Delivery ToolKit. Sparta codifies & automates “prerequisites” with an emphasis on extensibility, repeatability, and developer ease of use.


#### What problem does it solve?

The first generation CodeSparta was created to solve the complexity of delivering the Red Hat OpenShift Kubernetes Platform, along with middleware, and an application portfolio, within restricted deployment environments which may incur privilege restrictions & require building on pre-existing infrastructure. Sparta adapts to these requirements in highly complex target environments (e.g. behind an airgap) in a declarative, auditable, airgap capable, and automated fashion. Sparta continues to mature to meet a growing demand for it’s reliability & flexibility in enabling new and changing environments.


#### How does this magic work?

The delivery design centers around the Koffer and Konductor automation runtime engines as pluggable artifact collection and Infrastructure as Code (IaC) delivery engines. Additionally the CloudCtl “Lifecycle Deployment Services” pod augments cloud native features and or provides deployment time prerequisite services during IaC run cycles.


#### What are the different components that make up CodeSparta?

Koffer, Konductor, CloudCtl, and Jinx, are the heart of CodeSparta’s reliability & extensibility framework.


#### What is Koffer?

Koffer Engine is a containerized automation runtime for raking in various artifacts required to deploy Red Hat OpenShift Infrastructure, Middleware, and Applications into restricted and or air-gapped environments. Koffer is an intelligence void IaC runtime engine designed to execute purpose built external artifact “collector” plugins written in ansible, python, golang, bash, or combinations thereof.


#### What is Konductor?

Konductor is a human friendly RedHat UBI8 based Infrastructure As Code (IaC) development & deployment runtime which includes multiple cloud provider tools & devops deployment utilities. Included is a developer workspace for DevOps dependency & control as well as support for a unified local or remote config yaml for zero touch Koffer & Konductor orchestrated dynamic pluggable IaC driven platform delivery. It is a core component in creating the CloudCtl containerized services pod, and is intended for use in both typical & restricted or airgap network environments.


#### What is CloudCtl?

CloudCtl is a short lived “Lifecycle Services Pod” delivery framework designed to meet the needs of zero pre-existing infrastructure deployment or augment cloud native features for “bring your own service” scenarios. It provides a dynamic container based infrastructure service as code standard for consistent and reliable deployment, lifecycle, and outage rescue + postmortem operations tasks. It is designed to spawn from rudimentary Konductor plugin automation and is capable of dynamically hosting additional containerized services as needed. CloudCtl pod is fully capable of meeting any and all service delivery needs to deliver a cold datacenter “first heart beat” deployment with no prerequisites other than Podman installed on a single supported linux host and the minimum viable Koffer artifact bundles.


#### How do Sparta components work with each other?

All of Sparta’s core components were designed with declarative operation, ease of use, and bulletproof reliability as the crowning hierarchy of need. To that end these delivery tools were built to codify the repetitive and recyclable logic patterns into purpose built utilities and standards wrapped in minimalist declarative configuration. Each component is intended to support individual use. Unified orchestration is also supported from a single declarative ‘sparta.yml’ configuration file provided locally or called from remote https/s3 locations to support conformity with enterprise secret handling and version controlled end-to-end platform delivery.

Koffer creates standardized tar artifact bundles, including container images and git repo codebase(s) for the automated deployment & lifecycle maintenance of the platform.

Konductor consumes Koffer raked artifact bundles to unpack artifacts & IaC. It then orchestrates artifact delivery services & executes the packaged IaC to deliver the programmed capability. Konductor supports a declarative yaml configuration format, cli flags provided at runtime, or user-prompt style interaction to inform code requirements.

CloudCtl is a dynamic Konductor orchestrated framework for serving various deployment & lifecycle ops time infrastructure service requirements. CloudCtl is designed for extensible support of “bring your own” services including CoreDNS, Nginx, Docker Registry, ISC-DHCP, and Tftpd. CloudCtl is intended for use as a “last resort crutch” where pre-existing enterprise or cloud native supporting services are prefered if supported in the Konductor IaC plugins.


#### Method

Air-gapped and restricted network deliveries represent similar but critically unique challenges. Currently, Sparta delivers via an airgap only model, primarily aimed at pre-existing infrastructure and consisting of four distinct stages.


## Install Guide

The Sparta platform delivery ecosystem is maintained by contributors from Red Hat Consulting. This guide provides brief instructions on the basic Sparta platform delivery method to prepare and provision an air-gapped Red Hat OpenShift deployment on AWS GovCloud.


#### Overview of Steps for Air-gapped Deployment:



1. Prerequisite Tasks
2. Generate Offline Bundle
3. Import Artifacts to Air-gapped System
4. Air-gapped Deployment


### Prerequisite Tasks Page

Sparta is used to install OpenShift into a private, air-gapped VPC in AWS. The steps outlined in this document will use a DevKit to create a VPC in AWS. Additionally, the DevKit will provision a RHEL8 Bastion node (sparta-bastion-node) and a RH CoreOS node (sparta-registry-node) to act as a private registry for the install. 


#### Development Checklist:

Use this checklist to ensure prerequisites have been met:

[ ] AWS Commercial or GovCloud account Key Secret & ID Pair [see 1 below]

[ ] RHEL 8 Minimal AMI ID ([https://access.redhat.com/solutions/15356](https://access.redhat.com/solutions/15356) ) [see 2 below]

[ ] RH Quay pull secret ([https://cloud.redhat.com/openshift/install/metal/user-provisioned](https://cloud.redhat.com/openshift/install/metal/user-provisioned))

[ ] Internet connected linux terminal (ICLT) with:

    Packages:



*   Git
*   Podman
*   AWS CLI
1. AWS Security Credentials
    *   AWS Commercial (https://console.aws.amazon.com/iam/home#/security_credentials)
    *   AWS GovCloud ([https://console.amazonaws-us-gov.com/iam/home#/security_credentials](https://console.amazonaws-us-gov.com/iam/home#/security_credentials))
2. AWS RHEL 8 AMI
```
aws ec2 describe-images --owners 309956199498 --query 'sort_by(Images, &CreationDate)[*].[CreationDate,Name,ImageId]' --filters "Name=name,Values=RHEL-8.3*" "Name=architecture,Values=x86_64" --region us-east-2 --output table
```


### Deployment:

The Sparta DevKit VPC simulates air-gapped environments. It will create the required infrastructure to begin a development install. This will include:
* VPCs
    *   Private subnets (3 instances across availability zones)
    *   Public subnets (3 instances across availability zones)
* Security Groups
    *   Master security group
    *   Worker security group
    *   Registry security group
* IAM Roles
    *   Master IAM policy
    *   Worker IAM policy
* Bastion Node
* Registry Node
* Route 53 Configurations
* Internet gateway

For deployment on customer provided infrastructure, eg. VPC, please see [Appendix](#appendix) for qualifying configurations. After reading the appendix return here and proceed.

Perform these steps to setup the required infrastructure for an air-gapped OCP installation using Sparta DevKit VPC. 

From ICLT (Specified in Development Checklist):

1. Create AWS Key pair if needed. You may use an existing key if you like; note that we will refer to the name of the key as sparta throughout this doc. If using an existing key skip ahead to step #4
1. Create aws ssh key pair named sparta, this will download the file sparta.pem (https://docs.aws.amazon.com/cli/latest/userguide/cli-services-ec2-keypairs.html).  
1. Copy sparta.pem to a new working directory of your choice or the .ssh directory in your home directory  
1. Export the file path of the sparta.pem to an env var:  

```
export SPARTA_PRIVATE_KEY=[full path to sparta.pem]
```

5. Set the correct permissions on the new folder and pem file:

```
chmod 700 $(dirname $SPARTA_PRIVATE_KEY)
chmod 600 $SPARTA_PRIVATE_KEY
```

6. In that working directory run the following command: 

```
ssh-keygen -y -f \
    $SPARTA_PRIVATE_KEY > $(dirname $SPARTA_PRIVATE_KEY)/sparta.pub
```


7. Upload RHCOS AMI to AWS when in GovCloud

8. Use the following link for instructions on how to upload a RHCOS image as an AMI: ([https://docs.openshift.com/container-platform/4.8/installing/installing_aws/installing-aws-government-region.html#installation-aws-regions-with-no-ami_installing-aws-government-region](https://docs.openshift.com/container-platform/4.8/installing/installing_aws/installing-aws-government-region.html#installation-aws-regions-with-no-ami_installing-aws-government-region))

Here is a link to the required VMDK for the RHCOS AMI upload:
https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/latest/rhcos-aws.x86_64.vmdk.gz

9. If in the commercial cloud please find the ami for your region from the following link:
https://docs.openshift.com/container-platform/4.8/installing/installing_aws/installing-aws-user-infra.html#installation-aws-user-infra-rhcos-ami_installing-aws-user-infra


### Configure the Sparta DevKit VPC
1. Export the version of OpenShift to be deployed as an environment variable. The value 4.8.0 is the only supported value for this set of directions.

```
export OCP_VERSION=4.8.0
```

2. Clone the “devkit-vpc” repo.
If you are using an existing VPC that meets Sparta requirements(see [Appendix](#appendix)) replace `DEVKIT_BRANCH` in the command below with `existing-vpc`.
If you want the devkit to create your vpc for you replace `DEVKIT_BRANCH` in the command below with `$OCP_VERSION`.

```
git clone --branch [DEVKIT_BRANCH] \
   https://repo1.dso.mil/platform-one/distros/red-hat/ocp4/govcloud/devkit-vpc
```


3. Change directory to the “devkit-vpc” git repo

```
cd devkit-vpc
```


4. Configure terraform deployment variables:

```
vi variables.tf
```


5. Use the following table for assistance when setting the terraform deployment variables (Note: you’re only required to fill out the variables in this table, leave the remaining vars as is):

<br>
<table>
  <tr>
   <td>
<strong>Variable Name</strong>
   </td>
   <td><strong>Example</strong>
   </td>
   <td><strong>Explanation</strong>
   </td>
  </tr>
  <tr>
   <td>aws_ssh_key
   </td>
   <td>sparta
   </td>
   <td>Set this to the name of the AWS Key Pair created in step 2 of 'Deployment'. 
   </td>
  </tr>
  <tr>
   <td>ssh_pub_key
   </td>
   <td>to get this value execute the following command: `cat $(dirname $SPARTA_PRIVATE_KEY)/sparta.pub`
   </td>
   <td>The file content from the sparta.pub key create above
   </td>
  </tr>
  <tr>
   <td>rhcos_ami
   </td>
   <td>ami-0d5f9982f029fbc14
   </td>
   <td>The RH CoreOS AMI 
   </td>
  </tr>
  <tr>
   <td>vpc_id
   </td>
   <td>sparta or vpc-xxxxxxxxxxxxxxxxx
   </td>
   <td>If using an existing VPC set this to the VPC's ID, otherwise use the string 'sparta'.
   </td>
  </tr>
  <tr>
   <td>cluster_name
   </td>
   <td>sparta
   </td>
   <td>If using an existing VPC set this to the VPC's 'Name', otherwise use the string 'sparta'.
   </td>
  </tr>
  <tr>
   <td>cluster_domain
   </td>
   <td>sparta.io
   </td>
   <td>The base domain name for the OpenShift cluster
   </td>
  </tr>
  <tr>
   <td>bastion_ami
   </td>
   <td>ami-07da8bff8ee284be8
   </td>
   <td>The RHEL8 AMI, this will be used as the OS for the sparta-bastion created by the devkit-vpc script
   </td>
  </tr>
</table>

6. Launch the Sparta DevKit VPC replacing the -e args with your region and AWS key values:

```
./devkit-build-vpc.sh -vvv \ 
     -e aws_cloud_region=[AWS_REGION] \
     -e aws_access_key=[AWS_ACCESS_KEY] \
     -e aws_secret_key=[AWS_SECRET_KEY]
```


7. One of the things the above command created was an EC2 instance named ‘sparta-bastion-node’. Export the sparta-bastion-node public ip address into an env var. This can be found in the AWS EC2 web console:

```
export SPARTA_BASTION_NODE_PUBLIC_IP=[public ip of sparta-bastion-node]
```


8. Push AWS SSH keys sparta-bastion-host:

```
scp -i $SPARTA_PRIVATE_KEY \
  $SPARTA_PRIVATE_KEY \
  ec2-user@$SPARTA_BASTION_NODE_PUBLIC_IP:~/.ssh/
```


### Generate Offline Bundle

This step generates the offline OCP installer bundle.

From the ICLT (Specified in Development Checklist):



1. Create Platform Artifacts Staging Directory

```
mkdir -p ~/bundle
```


2. Build OpenShift Infrastructure, Operators, and App Bundles

Note you may need to adjust the config url based on your circumstances.

```
podman run -it --rm \
    --pull always \
    --volume ~/bundle:/root/bundle:z \
    quay.io/cloudctl/koffer:v00.21.0305 \
    bundle \
    --config https://raw.githubusercontent.com/RedHatGov/ocp-disconnected-docs/main/sparta/config.yml
```



Note: Paste the Quay.io Image Pull Secret referenced in the prerequisites section when prompted.



3. Verify the size of the bundle is approximately 7.4GB

```
du -sh ~/bundle/*
```



Example output, the version below would match the env var `OCP_VERSION` value:


```
7.4G	/home/ec2-user/bundle/koffer-bundle.openshift-4.8.0.tar
```



### Import Artifacts to Air-gapped System

This section details the procedures for transferring the platform bundle to the target air gap location when using the Sparta DevKit-VPC. 



1. From the ICLT, copy platform bundle to bastion

```
scp -i $SPARTA_PRIVATE_KEY -r ~/bundle \
       ec2-user@$SPARTA_BASTION_NODE_PUBLIC_IP:~
```


2. SSH from ICLT to sparta-bastion-node

```
ssh -i $SPARTA_PRIVATE_KEY ec2-user@$SPARTA_BASTION_NODE_PUBLIC_IP
```


3. Export the version of OpenShift to be deployed as an environment variable, ensure this is the same value as was set on the ICTL machine.

```
export OCP_VERSION=4.8.0
```


4. One of the things the devkit created was an EC2 instance named ‘sparta-registry-node’. Export the sparta-registry-node private ip address into an env var. This can be found in the AWS EC2 web console:

```
export SPARTA_REGISTRY_NODE_PRIVATE_IP=[private ip of sparta-registry-node]
```


5. Copy platform bundle to AWS EC2 instance named sparta-registry-node. 

```
scp -i ~/.ssh/sparta.pem -r ~/bundle \
    core@$SPARTA_REGISTRY_NODE_PRIVATE_IP:~
```


6. Extract platform bundle on sparta-registry-node

```
ssh -i ~/.ssh/sparta.pem -t core@$SPARTA_REGISTRY_NODE_PRIVATE_IP \
  "sudo tar xvf ~/bundle/koffer-bundle.sparta-aws-$OCP_VERSION.tar -C /root"
```




### Air-gapped Deployment

This step will deploy OCP into the DevKit VPC.

From the sparta-bastion-node:



1. SSH to the sparta-registry-node.

```
ssh  -i ~/.ssh/sparta.pem core@$SPARTA_REGISTRY_NODE_PRIVATE_IP
```


2. Acquire root

```
sudo -i
```

3. Run init.sh

```
cd /root/cloudctl && ./init.sh
```

4. Exec into Konductor

```
podman exec -it konductor connect
```

5. Edit cluster-vars.yml setting the variables as defined in the table below.

```
vim /root/platform/iac/cluster-vars.yml
```



<table>
  <tr>
   <td>
    <strong>Variable Name</strong>
   </td>
   <td><strong>Example</strong>
   </td>
   <td><strong>Explanation</strong>
   </td>
  </tr>
  <tr>
   <td>vpc_name
   </td>
   <td>sparta
   </td>
   <td>The AWS VPC Name for the target Environment
   </td>
  </tr>
  <tr>
   <td>name_domain
   </td>
   <td>spartadomain.io
   </td>
   <td>The domain name for the cluster
   </td>
  </tr>
  <tr>
   <td>vpc_id
   </td>
   <td>vpc-XXXXXXXXX
   </td>
   <td>The AWS VPC Id for the target environment
   </td>
  </tr>
  <tr>
   <td>aws_region
   </td>
   <td>us-east-1
   </td>
   <td>Set this to your target AWS region where OpenShift will be deployed
   </td>
  </tr>
  <tr>
   <td>aws_access_key_id
   </td>
   <td>AAAAAAAAAAAAAAAAAAAA
   </td>
   <td>AWS Key Id for the target environment
   </td>
  </tr>
  <tr>
   <td>aws_secret_access_key
   </td>
   <td>aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
   </td>
   <td>AWS Key Secret for the target environment
   </td>
  </tr>
  <tr>
   <td>rhcos_ami
   </td>
   <td>ami-XXXXXXXXX
   </td>
   <td>THE Red Hat CoreOS AMI Id for the target environment
   </td>
  </tr>
  <tr>
   <td>subnet_list
   </td>
   <td>
   - subnet-XXXXXXXXX
   - subnet-XXXXXXXXX
   - subnet-XXXXXXXXX
   </td>
   <td>The list of AWS Subnet Ids associated with the target VPC
   </td>
  </tr>
</table>
<br/>
<br/>


6. Deploy Cluster

```
cd /root/platform/iac/sparta && ./site.yml
```

7. Run the following commands, it ultimately runs a watch command. At the top of the output it will inform you when to move on to the next step;this may take 30-60 minutes.

```
function watch_command() {
  echo 
  echo

  ELB_HOST=$(oc get svc -n openshift-ingress | awk '/router-default/{print $4}')

  if [[ -n "$ELB_HOST" && "$ELB_HOST" != "<pending>" ]]; then
    echo "ready to run the next step..."
  else
    echo "the elb has not yet been created, continue waiting..."
  fi

  echo
  echo

  oc get co
}

export -f watch_command

watch -d -n 5 -c watch_command
```


8. Print & Load Apps ELB DNS CNAME Forwarder into apps route53 entry. To retrieve the wildcard DNS name run the following.

```
# prints the target value for the CNAME
oc get svc -n openshift-ingress | awk '/router-default/{print $4}'

# prints the CNAME value
echo "*.$(expr "$(oc get route -n openshift-console console | awk '/console/{print $2}')" : '[^.][^.]*\.\(.*\)')"
```


    1. Create a wildcard DNS record in your provider 
        1. value:  “*.apps.cluster.domain.io” (see output above for value)
        2. type: CNAME
        3. target: ELB CNAME (see output above for value)

1. Execute the following watch command and wait for the authentication and console operators to be available:

```
watch -d -n 5 oc get co
```


9. Run the following command to get the password for the kubeadmin user:


```
cat /root/platform/secrets/cluster/auth/kubeadmin-password
```


10. To get the url to the console:


```
oc whoami --show-console
```


11. In order to access the web console, we will need to connect to the private VPC. One way to do this is to simply use sshuttle ([https://sshuttle.readthedocs.io/en/stable/overview.html](https://sshuttle.readthedocs.io/en/stable/overview.html)) using the following commands.

From the ICLT host, run the following command to install Python 3.6 on the Sparta Bastion Node to support using sshuttle


```
ssh -i $SPARTA_PRIVATE_KEY -t ec2-user@$SPARTA_BASTION_NODE_PUBLIC_IP "sudo dnf -y install python36"
```


12. From the ICLT launch sshuttle to connect to the VPC


```
sshuttle  --dns -r ec2-user@$SPARTA_BASTION_NODE_PUBLIC_IP 0/0 \
  --ssh-cmd  "ssh -i $SPARTA_PRIVATE_KEY"
```


13. Now you can connect to the console using your browser of choice.


### Cluster & VPC Teardown Page Section

From the sparta-registry-node:



1. Exec into the container

```
sudo podman exec -it konductor bash
```



 



2. Change into the Terraform Directory

 


```
cd /root/platform/iac/shaman
```




3. Using the oc tool, patch the masters to make them schedulable

```
oc patch schedulers.config.openshift.io cluster -p '{"spec":{"mastersSchedulable":true}}' --type=merge
```


4. Delete machinesets & wait for worker nodes to terminate

```
for i in $(oc get machinesets -A | awk '/machine-api/{print $2}'); do oc delete machineset $i -n openshift-machine-api; echo deleted $i; done
```


5. Delete service router & wait for it to terminate

```
oc delete service router-default -n openshift-ingress &
```


6. Execute control plane breakdown playbook

 


```
chmod +x ./breakdown.yml && ./breakdown.yml
```


From the ICLT:

Change into the devkit-vpc directory

Execute breakdown script


```
./devkit-destroy-vpc.sh
```

### Appendix

#### VPC

The VPC name, id and IPv4 CIDR block will need to be provided at various points of the install process. Also, the cluster_name variable in the install will need to be set to the VPC name. 

VPC Example
```
Name tag: ${cluster_name}
IPv4 CIDR block: 10.0.0.0/16
IPv6 CIDR block:
```

#### Subnets

The install expects that there will be a public facing subnet group and a private subnet group. Additionally, each subnet group will span three availability zones.

Public Subnet Example
```
Name tag: ${cluster_name}-public-us-gov-west-1{a,b,c}
VPC: ${vpc_id}
Availability Zone: us-gov-west-1{a,b,c}
IPv4 CIDR block: 10.0.{0,1,2}.0/24
```

Private Subnet Example
```
Name tag: ${cluster_name}-private-us-gov-west-1{a,b,c}
VPC: ${vpc_id}
Availability Zone: us-gov-west-1{a,b,c}
IPv4 CIDR block: 10.0.{3,4,5}.0/2
```

#### Service Endpoints

Service Endpoints for EC2, Elastic Loadbalancer, and S3 will be needed during the install in order to access the AWS APIs for these services.

Service endpoint for S3 Example:
```
Service name: com.amazonaws.us-gov-west-1.s3
VPC: ${vpc_id}
Route table: ${private_route_table_id}
Custom:
{
  "Version": "2008-10-17",
  "Statement": [
	{
  	"Principal": "*",
  	"Action": "*",
  	"Effect": "Allow",
  	"Resource": "*"
	}
  ]
}
Tags:
Name: manual-test-pri-s3-vpce
“kubernetes.io/cluster/${cluster_name}", "owned" 
```

Service endpoint for EC2 Example:
```
Service name: com.amazonaws.us-gov-west-1.elasticloadbalancing
VPC: ${vpc_id}
Endpoint type: Interface
Private DNS: true
Security groups:  ${cluster_name}-elb-vpce
Subnets: ${private_subnet_ids}
Tags:
	Name: ${cluster_name}-elb-vpce
```

Service endpoint for ELB Example:
```
Service name: com.amazonaws.us-gov-west-1.elasticloadbalancing
VPC: ${vpc_id}
Endpoint type: Interface
Private DNS: true
Security groups:  ${cluster_name}-elb-vpce
Subnets: ${private_subnet_ids}
Tags:
	Name: ${cluster_name}-elb-vpce
```

#### Route 53

In addition to the VPC, There needs to be a private zone for the cluster subdomain in Route 53.

Hosted Zone Example
```
Domain Name: ${cluster_name}.${cluster_domain}
Type: private
```

After running the DevKit to create the Registry Node, a record will need to be added to the hosted zone for the registry node.

```
Record Name: registry.${cluster_name}.${cluster_domain}
Type: A
Routing Policy: Simple
Value/Route traffic to: ${registry_node_private_ipv4}
```
