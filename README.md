# What is CodeSparta?

In the simplest terms, CodeSparta is a target agnostic, additive, (Kubernetes) Private Cloud Trusted Platform Delivery ToolKit. Sparta codifies & automates "prerequisites" with an emphasis on extensability, repeatability, and developer ease of use.

### What problem does it solve?

The first generation CodeSparta was created to solve the complexity of delivering the Red Hat OpenShift Kubernetes Platform, along with middleware, and an application portfolio, within restricted deployment environments which may incur privilege restrictions & require building on pre-existing infrastructure. Sparta adapts to these requirements in highly complex target environments (e.g. behind an [airgap](https://en.wikipedia.org/wiki/Air_gap_(networking)#:~:text=An%20air%20gap%2C%20air%20wall,an%20unsecured%20local%20area%20network.)) in a declarative, auditable, airgap capable, and automated fashion. Sparta continues to mature to meet a growing demand for it's reliability & flexibility in enabling new and changing environments.

### How does this magic work?

The delivery design centers around the Koffer and Konductor automation runtime engines as pluggable artifact collection and Infrastructure as Code (IaC) delivery engines. Additionally the CloudCtl "Lifecycle Deployment Services" pod augments cloud native features and or provides deployment time prerequisite services during IaC run cycles.

### What are the different components that make up CodeSparta?

Koffer, Konductor, CloudCtl, and Jinx, are the heart of CodeSparta's reliability & extensibility framework.

### What is Koffer?

[Koffer](https://github.com/CodeSparta/Koffer) Engine is a containerized automation runtime for raking in various artifacts required to deploy Red Hat OpenShift Infrastructure, Middleware, and Applications into restricted and or airgapped environments. Koffer is an intelligence void IaC runtime engine designed to execute purpose built external artifact "collector" plugins written in ansible, python, golang, bash, or combinations thereof.

### What is Konductor?

[Konductor](https://github.com/CodeSparta/Konductor) is a human friendly RedHat UBI8 based Infrastructure As Code (IaC) development & deployment runtime which includes multiple cloud provider tools & devops deployment utilities. Included is a developer workspace for DevOps dependency & control as well as support for a unified local or remote config yaml for zero touch Koffer & Konductor orchestrated dynamic pluggable IaC driven platform delivery. It is a core compoment in creating the CloudCtl containerized services pod, and is intended for use in both typical & restricted or airgap network environments.

### What is CloudCtl?

[CloudCtl](https://github.com/CodeSparta/CloudCtl) is a short lived "Lifecycle Services Pod" delivery framework designed to meet the needs of zero pre-existing infrastucture deployment or augment cloud native features for "bring your own service" scenarios. It provides a dynamic container based infrastructure service as code standard for consistent and reliable deployment, lifecycle, and outage rescue + postmortem operations tasks. It is designed to spawn from rudimentary Konductor plugin automation and is capable of dynamically hosting additional containerized services as needed. CloudCtl pod is fully capable of meeting any and all service delivery needs to deliver a cold datacenter "first heart beat" deployment with no prerequisites other than Podman installed on a single supported linux host and the minimum viable Koffer artifact bundles.

### How do Sparta components work with each other?

All of Sparta's core components were designed with declarative operation, ease of use, and bulletproof reliability as the crowning hierarchy of need. To that end these delivery tools were built to codify the repetative and recycleable logic patterns into purpose built utilities and standards wrapped in minimalist declarative configuration. Each component is intended to support individual use. Unified orchestration is also supported from a single declarative 'sparta.yml' configuration file provided locally or called from remote https/s3 locations to support conformity with enterprise secret handling and version controlled end-to-end platform delivery.

[Koffer](https://github.com/CodeSparta/Koffer) creates standardized tar artifact bundles, including container images and git repo codebase(s) for the automated deployment & lifecycle maintenance of the platform.

[Konductor](https://github.com/CodeSparta/Konductor) consumes Koffer raked artifact bundles to unpack artifacts & IaC. It then orchestrates artifact delivery services & executes the packaged IaC to deliver the programmed capability. Konductor supports a declarative yaml configuration format, cli flags provided at runtime, or user-prompt style interaction to inform code requirements.

[CloudCtl](https://github.com/CodeSparta/CloudCtl) is a dynamic Konductor orchestrated framework for serving various deployment & lifecycle ops time infrastructure service requirements. CloudCtl is designed for extensable support of "bring your own" services including CoreDNS, Nginx, Docker Registry, ISC-DHCP, and Tftpd. CloudCtl is intended for use as a "last resort crutch" where pre-existing enterprise or cloud native supporting services are prefered if supported in the Konductor IaC plugins.

# Glossary
### What is a tarball?

[Tarball](https://en.wikipedia.org/wiki/Tarball) may refer to: tar (computing), a computer file format that combines and compresses multiple files.

### What is an airgaped environment?

An [air gap, air wall, air gapping or disconnected network](https://en.wikipedia.org/wiki/Air_gap_(networking)#:~:text=An%20air%20gap%2C%20air%20wall,an%20unsecured%20local%20area%20network.) is a network security measure employed on one or more computers to ensure that a secure computer network is physically isolated from unsecured networks, such as the public Internet or an unsecured local area network.

In environments where networks or devices are rated to handle different levels of classified information, the two disconnected devices or networks are referred to as "low side" and "high side", "low" being unclassified and "high" referring to classified, or classified at a higher level.

### What is a network enclave?

A [Network Enclave](https://en.wikipedia.org/wiki/Network_enclave) is a section of an internal network that is subdivided from the rest of the network.

### What is an artifact in Computer Science?

An [artifact](https://en.wikipedia.org/wiki/Artifact_(software_development)) is one of many kinds of tangible by-products produced during the development of software. Some artifacts (e.g., use cases, class diagrams, and other Unified Modeling Language (UML) models, requirements and design documents) help describe the function, architecture, and design of software. Other artifacts are concerned with the process of development itself—such as project plans, business cases, and risk assessments.

### What is a pipeline?

A [pipeline](https://www.bmc.com/blogs/deployment-pipeline/) in a Software Engineering team is a set of automated processes that allow Developers and DevOps professionals to reliably and efficiently compile, build and deploy their code to their production compute platforms.

### What are some pipeline tooling available today?

[Some Pipeline tools](https://resources.whitesourcesoftware.com/blog-whitesource/devops-pipeline)

### What is a container?

A [container](https://www.docker.com/resources/what-container#:~:text=A%20container%20is%20a%20standard,one%20computing%20environment%20to%20another.&text=Available%20for%20both%20Linux%20and,same%2C%20regardless%20of%20the%20infrastructure.) is a standard unit of software that packages up code and all its dependencies so the application runs quickly and reliably from one computing environment to another. 

### What is a pod?

[Pods](https://cloud.google.com/kubernetes-engine/docs/concepts/pod) are the smallest, most basic deployable objects in Kubernetes. A [Pod](https://kubernetes.io/docs/concepts/workloads/pods/) represents a single instance of a running process in your cluster.

Pods contain one or more containers, such as Docker containers. When a Pod runs multiple containers, the containers are managed as a single entity and share the Pod's resources. Generally, running multiple containers in a single Pod is an advanced use case.

### What is a container registry?

A [container registry](https://searchcloudcomputing.techtarget.com/definition/container-registry#:~:text=A%20container%20registry%20is%20a,applications%20in%20a%20single%20instance.) is a collection of repositories made to store container images. A container image is a file comprised of multiple layers which can execute applications in a single instance

### What is a runtime environment?

Everything you need to execute a program, but no tools to change it. In short, [Runtime](https://stackoverflow.com/questions/3710130/what-is-run-time-environment) environment is for the program, what physical environment is to us.

### What is a build environment?

Given some code written by someone, everything you need to compile it or otherwise prepare an executable that you put into a Run time environment. Build environments are pretty useless unless you can see tests what you have built, so they often include Run too. In Build you can't actually modify the code.

### What is a development environment?

Everything you need to write code, build it and test it. Code Editors and other such tools. Typically also includes Build and Run.

### What is Kubernetes?
[Kubernetes](https://kubernetes.io/docs/concepts/overview/what-is-kubernetes/) is a portable, extensible, open-source platform for managing containerized workloads and services, that facilitates both declarative configuration and automation.
