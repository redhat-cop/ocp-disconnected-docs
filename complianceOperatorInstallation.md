# Disconnected OpenShift Compliance Operator Installation

## Overview

This guide is intended to demonstrate how to install the OpenShift [Compliance Operator](https://github.com/ComplianceAsCode/content) into disconnected OpenShift environments.

The process of installing the OpenShift Compliance Operator can be broke down into three major steps:
1. Bundling (Internet Connected)
2. Mirroring (Disconnected)
3. Installation (Disconnected)

## Bundling

Perform the following steps on an internet connected host.

1. Clone the (unofficial) OpenShift Operator mirroring utility:  
```
git clone https://github.com/RedHatGov/openshift-disconnected-operators.git
```
2. Retrieve OpenShift Pull Secret from: https://cloud.redhat.com/openshift/install/aws/installer-provisioned

3. Run Compliance Operator convenience bundler:
```
cd openshift-disconnected-operators
./container/container-launch.sh ./bundle.sh '<< Pull Secret>>'
```
*Note, ensure pull secret is entered between literals.
*Note, This process bundles the latest version of operators. Refer to the openshift-disconnected-operators' README for advanced usage.



