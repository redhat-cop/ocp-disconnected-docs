## What is OpenShift?

Red Hat OpenShift is a leading enterprise Kubernetes platform, purpose-built for innovation. The latest release, version 4.6, comes with a number of enhancements focused on enabling our government customers to accelerate and expand their adoption of containers and DevSecOps, such as a comprehensive approach to FIPS, expanded support for government clouds, an automated approach to compliance via the Compliance Operator, and others. 

Red Hat OpenShift is a certified Kubernetes distribution, which provides consistency via the Kubernetes API, timely updates, and confirmability to ensure interoperability. Red Hat is a leading contributor to Kubernetes and other projects in this ecosystem including Linux, Prometheus, Jaeger, CNI, Envoy, Istio, etc. At Red Hat we use a 100% open source development model to deliver enterprise products.  No fork, no rebase, no proprietary extensions.

Red Hat emphasizes the enterprise supportability of open source software, which is particularly important with the DoD mission. Not only do they build an ecosystem of supported partners and vendors. We recognize that keeping up with the frequent upstream releases can be challenging and we’re investing in automated capabilities like the operator framework and over-the-air updates to make it easier to keep up to date with the latest innovations coming out of the communities and to deploy containers at scale.

For more information on OpenShift 4.6, please refer to [this blog](https://www.openshift.com/blog/red-hat-openshift-4.6-the-kubernetes-platform-for-government).


## How do you install OpenShift?

There are two native ways of installing OpenShift, Installer Provisioned Infrastructure (IPI) and User Provisioned Infrastructure (UPI). Both produce highly available, fully capable OpenShift clusters, the only difference is who is responsible for provisioning the required infrastructure. 

Additionally, you can create your own custom automation around a UPI install to target a specific use case or environment such as Cloud One. An example of this is Sparta, which is a tool incepted by Red Hat Consulting to help facilitate installs in Cloud One or similarly restricted AWS environments.

In this section, we will be diving into what each approach entails then discussing the merits of each approach relative to a DoD use case.

**Installer Provisioned Infrastructure (IPI)**

For clusters with installer-provisioned infrastructure (IPI), you delegate the infrastructure bootstrapping and provisioning to the installation program instead of doing it yourself. The installation program creates all of the networking, machines, and operating systems that are required to support the cluster. There are some aspects that are configurable such as the number of machines that the control plane uses, the type of virtual machine that the cluster deploys, or the CIDR range for the Kubernetes service network. However, generally speaking, for highly customized installations a User Provisioned Infrastructure (UPI) approach will be required.

**User Provisioned Infrastructure (UPI)**

If you provision and manage the infrastructure for your cluster yourself, you must provide all of the cluster infrastructure and resources, including:



*   The underlying infrastructure for the control plane and compute machines that make up the cluster
*   Load balancers (for the cluster, OpenShift will create software proxies in front of any application workloads automatically)
*   Cluster networking (i.e. VPCs) and required subnets
*   DNS records for the cluster
*   Storage for the cluster infrastructure

Red Hat provides cloud-provider templates to help you get started in building your infrastructure. The customer has the option to leverage these Red Hat provided templates or build custom automation to build out infrastructure. Linked here are the guides for AWS and Azure, but more are available for other providers:



*   AWS CloudFormation templates: [https://docs.openshift.com/container-platform/4.6/installing/installing_aws/installing-aws-user-infra.html#installation-aws-user-infra-requirements_installing-aws-user-infra](https://docs.openshift.com/container-platform/4.6/installing/installing_aws/installing-aws-user-infra.html#installation-aws-user-infra-requirements_installing-aws-user-infra) 
*   Azure ARM templates: [https://docs.openshift.com/container-platform/4.6/installing/installing_azure/installing-azure-user-infra.html#installation-azure-user-infra-config-project](https://docs.openshift.com/container-platform/4.6/installing/installing_azure/installing-azure-user-infra.html#installation-azure-user-infra-config-project) 

**What is Sparta?**

Sparta is a customized UPI install with additional tools to help facilitate a disconnected build to the requirements of Cloud One’s IL2 AWS GovCloud environment (C1DL). Some of the unique challenges in that environment include:


*   Disconnected AWS GovCloud
*   Can’t create IAM roles
*   Can’t create ELBs
*   Existing VPCs configured specifically for C1DL
*   Can’t modify subnets or route tables
*   Multiple subnets provided for different purposes (common, apps, etc.)

An architecture overview for Sparta is available [here](https://codectl.io/docs/overview) and the [github page](https://github.com/CodeSparta).

Sparta is under continuous development to continue to better target the use cases of our DoD customers.

**Considerations When Installing OpenShift Disconnected**

OpenShift installed via any of these methods can be installed disconnected. It does not require connectivity to the internet to function with the exception of cloud provider APIs. Even the cloud provider APIs are not strictly required but you will lose the ability to leverage the cloud provider plugin which provides native integration with the underlying cloud services. This plugin allows for some advanced machine management and scaling capabilities, including: 



*   Integration with in-tree storage providers for the cloud (e.g. gp2 storage class for EBS volumes in AWS) allowing you to dynamically provision storage. This functionality can be added separately using the CSI drivers for the cloud if you do not have cloud integration enabled.
*   Machine integration to enable easy adding/removing nodes from the cluster. This is functionality that cluster autoscaling relies on to work.
*   Setting up and configuring object (S3) storage for the internal OpenShift container registry.
*   Automatic configuration of load balancers and DNS entries (if enabled) for the OpenShift router.

The primary consideration when installing disconnected is taking the install content (container images, operators, iso/ova/ovf etc.) to the high side where it needs to be hosted in a content repository. If the environment already has an existing container registry, the container images can be loaded into it to support the installation. Additionally, a web server is needed to host the operating system image and the configuration files for the RHCOS nodes. This content needs to be accessible from the environment where the nodes will be deployed and from the host where the installation is performed from.

**Comparing IPI, UPI, and Sparta for the DoD Requirements**

The table below will compare features of IPI vs UPI to help you decide what is best for your organization.


<table>
  <tr>
   <td>
   </td>
   <td><strong>IPI</strong>
   </td>
   <td><strong>UPI</strong>
   </td>
   <td><strong>Sparta</strong>
   </td>
  </tr>
  <tr>
   <td>Can be installed in disconnected environment
   </td>
   <td>Yes
   </td>
   <td>Yes
   </td>
   <td>Yes
   </td>
  </tr>
  <tr>
   <td>Installs highly available cluster
   </td>
   <td>Yes
   </td>
   <td>Yes
   </td>
   <td>Yes
   </td>
  </tr>
  <tr>
   <td>Can be installed in AWS, Azure, GCP, VMWare, RHV, OpenStack
   </td>
   <td>Yes
   </td>
   <td>Yes
   </td>
   <td>No, AWS only, on roadmap to expand
   </td>
  </tr>
  <tr>
   <td>Can be installed bare metal
   </td>
   <td>Yes, but only on certain hardware
   </td>
   <td>Yes
   </td>
   <td>No
   </td>
  </tr>
  <tr>
   <td>Can be installed in existing VPCs (or Azure VNETs)
   </td>
   <td>Yes (<a href="https://www.openshift.com/blog/deploy-openshift-to-existing-vpc-on-aws">see blog</a>)
   </td>
   <td>Yes
   </td>
   <td>Yes
   </td>
  </tr>
  <tr>
   <td>Requires full administrative privileges
   </td>
   <td>By default yes, but can also pre-create less privileged IAM roles (see docs for <a href="https://docs.openshift.com/container-platform/4.6/installing/installing_aws/manually-creating-iam.html">AWS</a> and <a href="https://docs.openshift.com/container-platform/4.6/installing/installing_azure/manually-creating-iam-azure.html">Azure</a>)
   </td>
   <td>No
   </td>
   <td>No
   </td>
  </tr>
  <tr>
   <td>Requires Route 53 (or Azure DNS)
   </td>
   <td>Yes
   </td>
   <td>No
   </td>
   <td>Yes, but on the roadmap to allow other options
   </td>
  </tr>
  <tr>
   <td>Can be installed in C2S
   </td>
   <td>No
   </td>
   <td>Yes
   </td>
   <td>No, but on roadmap
   </td>
  </tr>
  <tr>
   <td>Can be installed with existing ELB
   </td>
   <td>No
   </td>
   <td>Yes
   </td>
   <td>Yes
   </td>
  </tr>
  <tr>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
  </tr>
</table>



## Getting Started

In this section, we will walk you through installations using each of the methods described above.

### Installing OpenShift in Disconnected Microsoft Azure Government using IPI

[OpenShift IPI on MAG](IPIonMAGInstall.md)

[OpenShift IPI on MAG with Manual IAM](IPIonMAGInstallManualIAM.md)

## Installing OpenShift in Disconnected AWS GovCloud using Sparta

[Sparta Install Docs](SpartaInstall.md)

