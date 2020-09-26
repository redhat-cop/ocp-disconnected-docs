# Wiki
## What is CodeSparta?

## What problem does it solve?

Sparta was created to solve the problem of delivering the Red Hat OpenShift Kubernetes Platform, along with an exstensible middleware and application portfolio, within restricted deployment environments (e.g. behind an airgap).

## How is it solving it?

The delivery design centers around the Koffer and Konductor automation runtime containers as pluggable artifact collection and Infrastructure as Code (IaC) delivery engines, which orchestrates the CloudCtl deployment services pod to augment cloud native features.

## What are the different components that make up CodeSparta?

The different componenets that make up CodeSparta are: Koffer, Konductor, and Cloudctl

## What is Koffer?

Koffer Engine is an ansible automation runtime for raking in various artifacts required to deploy Red Hat OpenShift Infrastructure, Pipelines, and applications into airgaped environments. Koffer is strictly an empty engine and is designed to run against compliant external collector plugin repos.

## What is Konductor?

Konductor is a SSH & TMUX enabled UBI8 based Infrastructure As Code (IaC) development & deployment sandbox which includes multiple cloud provider tools & devops deployment utilities, it provides a human workspace for DevOps dependency & control. It is a core compoment of the CloudCtl bastion Podman container Pod, and is intended for use in both typical & restricted or airgap network environments.

## What is Cloudctl?

Cloudctl is a DevOps Deployment Services & Utilities Container Pod Infrastructure as Code toolkit. It provides a container based Infrastructure as Code toolkit for deployment operations tasks. Its core features are delivered via the UBI8 based Konductor as its primary orchestration base. It is capable of dynamically allocating additional pod contained services.

## How do does components work with each other?

Koffer creates tar bundles of required images for the deployment of the platform, place them in unencrypted storage medium, Konductor then prompt the user some sensitive information, ie Terraform vars, OCP ignition, secrets, etc... creates a manifest with newly received data, then store those data in encrypted storage medium, Konductor then pulls the tar bundles created by Koffer from the unencrypted storage medium, as well as the manifest from the encrypted storage medium, then deploys Cloudctl and the OpenShift cluster. Different components from the OpenShift cluster pull what's needed for their provisionement from Cloudctl.

## What is a container?

A [container](https://www.docker.com/resources/what-container#:~:text=A%20container%20is%20a%20standard,one%20computing%20environment%20to%20another.&text=Available%20for%20both%20Linux%20and,same%2C%20regardless%20of%20the%20infrastructure.) is a standard unit of software that packages up code and all its dependencies so the application runs quickly and reliably from one computing environment to another. 

## What is a pod?

[Pods](https://cloud.google.com/kubernetes-engine/docs/concepts/pod) are the smallest, most basic deployable objects in Kubernetes. A [Pod](https://kubernetes.io/docs/concepts/workloads/pods/) represents a single instance of a running process in your cluster.

Pods contain one or more containers, such as Docker containers. When a Pod runs multiple containers, the containers are managed as a single entity and share the Pod's resources. Generally, running multiple containers in a single Pod is an advanced use case.

## What is a container registry?

A [container registry](https://searchcloudcomputing.techtarget.com/definition/container-registry#:~:text=A%20container%20registry%20is%20a,applications%20in%20a%20single%20instance.) is a collection of repositories made to store container images. A container image is a file comprised of multiple layers which can execute applications in a single instance

## What is a runtime environment?

Everything you need to execute a program, but no tools to change it. In short, [Runtime](https://stackoverflow.com/questions/3710130/what-is-run-time-environment) environment is for the program, what physical environment is to us.

## What is a build environment?

Given some code written by someone, everything you need to compile it or otherwise prepare an executable that you put into a Run time environment. Build environments are pretty useless unless you can see tests what you have built, so they often include Run too. In Build you can't actually modify the code.

## What is a development environment?

Everything you need to write code, build it and test it. Code Editors and other such tools. Typically also includes Build and Run.

## Why is it needed?

## What is Kubernetes?
[Kubernetes](https://kubernetes.io/docs/concepts/overview/what-is-kubernetes/) is a portable, extensible, open-source platform for managing containerized workloads and services, that facilitates both declarative configuration and automation. 

## What is a pipeline?

A [pipeline](https://www.bmc.com/blogs/deployment-pipeline/) in a Software Engineering team is a set of automated processes that allow Developers and DevOps professionals to reliably and efficiently compile, build and deploy their code to their production compute platforms.
## What are some pipeline tooling available today?

[Some Pipeline tools](https://resources.whitesourcesoftware.com/blog-whitesource/devops-pipeline)

## What is an airgaped environment?

An [air gap, air wall, air gapping or disconnected network](https://en.wikipedia.org/wiki/Air_gap_(networking)#:~:text=An%20air%20gap%2C%20air%20wall,an%20unsecured%20local%20area%20network.) is a network security measure employed on one or more computers to ensure that a secure computer network is physically isolated from unsecured networks, such as the public Internet or an unsecured local area network.

In environments where networks or devices are rated to handle different levels of classified information, the two disconnected devices or networks are referred to as "low side" and "high side", "low" being unclassified and "high" referring to classified, or classified at a higher level.

## What is a tarball?

[Tarball](https://en.wikipedia.org/wiki/Tarball) may refer to: tar (computing), a computer file format that combines and compresses multiple files. 

## What is an artifact in Computer Science?

An [artifact](https://en.wikipedia.org/wiki/Artifact_(software_development)) is one of many kinds of tangible by-products produced during the development of software. Some artifacts (e.g., use cases, class diagrams, and other Unified Modeling Language (UML) models, requirements and design documents) help describe the function, architecture, and design of software. Other artifacts are concerned with the process of development itself—such as project plans, business cases, and risk assessments.

## What is a network enclave?

A [Network Enclave](https://en.wikipedia.org/wiki/Network_enclave) is a section of an internal network that is subdivided from the rest of the network.





