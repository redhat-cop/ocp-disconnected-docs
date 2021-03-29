# Installing Azure Red Hat OpenShift (ARO) in Disconnected Microsoft Azure

## Overview

This guide will demonstrate how to install an Azure Red Hat OpenShift (ARO) cluster on an existing disconnected network in Microsoft Azure.  The network will disallow inbound connections from the internet.  The network will restrict outbound connections to the internet, allowing only the following endpoints:

*  `*azure.com *microsoft.com`
*  `*microsoftonline.com`
*  `*windows.net`

Note that restricting outbound connections entirely violates the [Azure Red Hat OpenShift support policy](https://docs.microsoft.com/en-us/azure/openshift/support-policies-v4#cluster-configuration-requirements).

## Installation



## Smoke Test

