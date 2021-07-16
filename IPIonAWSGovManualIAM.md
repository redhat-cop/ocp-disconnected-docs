# Installing OpenShift in Disconnected AWS GovCloud using IPI

## NOTICE: OpenShift 4.7.10 may not install into GovCloud. Please see https://bugzilla.redhat.com/show_bug.cgi?id=1958420 for more info.
## Overview

This guide is intended to demonstrate how to perform the OpenShift installation using the IPI method on AWS GovCloud. In addition, the guide will walk through performing this installation on an existing disconnected network. In other words the network does not allow access to and from the internet.

## YouTube Video

A video that walks through this guide is available here: https://youtu.be/bHmcWHF-sEA

## AWS Configuration Requirements for Demo
<figure>
  <img src="./aws-gov-ipi-dis-maniam/aws-gov-vpc-drawing.svg" width="800"/>
  <figcaption>Image: Demo VPC Drawing</figcaption>
  <p></p>
</figure>
   
   

In this guide, we will install OpenShift onto an existing AWS GovCloud VPC. This VPC will contain three private subnets that have no connectivity to the internet, as well as a public subnet that will facilitate our access to the private subnets from the internet (bastion). We still need to allow access to the AWS APIs from the private subnets. For this demo, that AWS API communication is facilitated by a squid proxy. Without that access, we will not be able to install a cloud aware OpenShift cluster. 

This guide will assume that the user has valid accounts and subscriptions to both Red Hat OpenShift and AWS GovCloud.

A Cloud Formation template that details the VPC with squid proxy used in this demo can be found [**here**](https://raw.githubusercontent.com/redhat-cop/ocp-disconnected-docs/main/aws-gov-ipi-dis-maniam/cloudformation.yaml). 

Before running the cloud formation, ensure the following is created.

1. A key-pair. This command will pull your local public key.
```sh
aws ec2 import-key-pair --key-name disconnected-east-1 --public-key-material fileb://~/.ssh/id_rsa.pub
```

2. The VPC Network & Subnets. Copy the cloud formation file to your local directory before running.
```sh
aws cloudformation create-stack --stack-name ocpdd --template-body file://./cloudformation.yaml --capabilities CAPABILITY_IAM
```

3. Bastion on Public Subnet on VPC created
- Allow 22 (default)
- Ensure at least 50G of disk space is allocated

Register the machine and ensure the following packages are installed
- podman
- unzip
- aws-cli (see https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html#cliv2-linux-install)

4. Private registry on Private Subnet on VPC created
- Allow 22 (default)
- Allow 5000
- Ensure at least 50G of disk space is allocated
_You may wish to generate another key on the public bastion and add it's public key here before creation. Use the same method as step 1 on the bastion with a unique name._

Ensure the following binaries are transferred and installed
- https://github.com/itchyny/gojq (mv release and rename to /usr/bin/jq)
- aws-cli (transfer the install directory and run the install)

#
## Installing OpenShift 

### Create OpenShift Installation Bundle
1. Download and compress the stable release bundle on internet an connected machine using the OpenShift4-mirror companion utility found **[here](https://github.com/redhat-cop/ocp-disconnected-docs.git)**
   

   You will first need to retrieve an OpenShift pull secret. Once you have retrieved that, enter it into the literals of the value for `--pull-secret` in the command below. Pull secrets can be obtained from https://cloud.redhat.com/openshift/install/aws/installer-provisioned

    ```bash
    OCP_VER=$(curl http://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/release.txt 2>&1 | grep -oP "(?<=Version:\s\s).*")
    podman run -it --security-opt label=disable -v ./:/app/bundle quay.io/redhatgov/openshift4_mirror:latest \
      ./openshift_mirror bundle \
      --openshift-version ${OCP_VER} \
      --platform aws \
      --skip-existing \
      --skip-catalogs \
      --pull-secret ${PULL_SECRET} && \
    git clone https://github.com/redhat-cop/ocp-disconnected-docs.git ./${OCP_VER}/ocp-disconnected && \
    tar -zcvf openshift-${OCP_VER}.tar.gz ${OCP_VER}
    ```
2. Transfer bundle from internet connected machine to disconnected vpc host.

#
### Prepare and Deploy
3. Extract bundle on disconnected vpc host. From the directory containing the OCP bundle.
    ```bash
    OCP_VER=$(ls | grep -oP '(?<=openshift-)\d\.\d\.\d(?=.tar.gz)')    
    tar -xzvf openshift-${OCP_VER}.tar.gz
    ```

4. Create S3 Bucket and attach policies.

    ```bash
    export awsreg=$(aws configure get region)
    export s3name=$(date +%s"-rhcos")
    aws s3api create-bucket --bucket ${s3name} --region ${awsreg} --create-bucket-configuration LocationConstraint=${awsreg}
    aws iam create-role --role-name vmimport --assume-role-policy-document "file://${OCP_VER}/ocp-disconnected/aws-gov-ipi-dis-maniam/trust-policy.json"
    envsubst < ./${OCP_VER}/ocp-disconnected/aws-gov-ipi-dis-maniam/role-policy-templ.json > ./${OCP_VER}/ocp-disconnected/aws-gov-ipi-dis-maniam/role-policy.json
    aws iam put-role-policy --role-name vmimport --policy-name vmimport --policy-document "file://${OCP_VER}/ocp-disconnected/aws-gov-ipi-dis-maniam/role-policy.json"
    ```

5. Upload RHCOS Image to S3

    ```bash
    export RHCOS_VER=$(ls ./${OCP_VER}/rhcos/ | grep -oP '.*(?=\.vmdk.gz)')
    gzip -d ./${OCP_VER}/rhcos/${RHCOS_VER}.vmdk.gz
    aws s3 mv ./${OCP_VER}/rhcos/${RHCOS_VER}.vmdk s3://${s3name}
    ```

6. Create AMI

    ```bash
    envsubst < ./${OCP_VER}/ocp-disconnected/aws-gov-ipi-dis-maniam/containers-templ.json > ./${OCP_VER}/ocp-disconnected/containers.json
    taskid=$(aws ec2 import-snapshot --region ${awsreg} --description "rhcos-snapshot" --disk-container file://${OCP_VER}/ocp-disconnected/containers.json | jq -r '.ImportTaskId')
    until [[ $resp == "completed" ]]; do sleep 2; echo "Snapshot progress: "$(aws ec2 describe-import-snapshot-tasks --region ${awsreg} | jq --arg task "$taskid" -r '.ImportSnapshotTasks[] | select(.ImportTaskId==$task) | .SnapshotTaskDetail.Progress')"%"; resp=$(aws ec2 describe-import-snapshot-tasks --region ${awsreg} | jq --arg task "$taskid" -r '.ImportSnapshotTasks[] | select(.ImportTaskId==$task) | .SnapshotTaskDetail.Status'); done
    snapid=$(aws ec2 describe-import-snapshot-tasks --region ${awsreg} | jq --arg task "$taskid" '.ImportSnapshotTasks[] | select(.ImportTaskId==$task) | .SnapshotTaskDetail.SnapshotId')
    aws ec2 register-image \
      --region ${awsreg} \
      --architecture x86_64 \
      --description "${RHCOS_VER}" \
      --ena-support \
      --name "${RHCOS_VER}" \
      --virtualization-type hvm \
      --root-device-name '/dev/xvda' \
      --block-device-mappings 'DeviceName=/dev/xvda,Ebs={DeleteOnTermination=true,SnapshotId='${snapid}'}' 
    ```

7. Record the AMI ID from the output of the above command.

8. Create registry cert on disconnected vpc host
    ```bash
    export SUBJ="/C=US/ST=Virginia/O=Red Hat/CN=${HOSTNAME}"
    openssl req -newkey rsa:4096 -nodes -sha256 -keyout registry.key -x509 -days 365 -out registry.crt -subj "$SUBJ" -addext "subjectAltName = DNS:$HOSTNAME"
    ```    

9. Make a copy of the install config
    ```bash
    mkdir ./${OCP_VER}/config
    cp ./${OCP_VER}/ocp-disconnected/aws-gov-ipi-dis-maniam/install-config-template.yaml ./${OCP_VER}/config/install-config.yaml
    ```
10. Edit install config
    For this step, Open `./${OCP_VER}/config/install-config.yaml` and edit the following fields:

    ```yaml
    baseDomain: i.e. example.com
    additionalTrustBundle: copy and paste the content of ./registry.crt here.
    imageContentSources:
      mirrors: Only edit the registry hostname fields of this section. Make sure that you use the $HOSTNAME of the devices that you are currently using.
    metadata:
      name: i.e. test-cluster
    networking:
      machineNetwork:
      - cidr: i.e. 10.0.41.0/20. Shorten or lengthen this list as needed.
    platform:
      aws:
        region: the default region of your configured aws cli 
        zones: A list of availability zones that you are deploying into. Shorten or lengthen this list as needed.
        subnets: i.e. subnet-ef12d288. The length of this list must match the .networking.machineNetwork[].cidr length.
        amiID: the AMI ID recorded from step 9
        pullSecret: your pull secret enclosed in literals
        sshKey: i.e ssh-rsa AAAAB3... No quotes
    ```
    Don't forget to save and close the file!

11. Make a backup of the final config:
    ```bash
    cp -R ./${OCP_VER}/config/ ./${OCP_VER}/config.bak
    ```

12. Create manifests from install config.
    ```bash
    openshift-install create manifests --dir ./${OCP_VER}/config
    ```

13. create iam users and Policies

    ```bash
    cd ./${OCP_VER}/ocp-disconnected/aws-gov-ipi-dis-maniam
    chmod +x ./ocp-users.sh
    ./ocp-users.sh prepPolicies
    ./ocp-users.sh createUsers
    ```

14. Use the convenience script to create the aws credentials and kubernetes secrets:
    ```bash
    chmod +x ./secret-helper.sh
    ./secret-helper.sh
    cp secrets/* ../../config/openshift/
    cd -
    ```

15. start up the registry in the background
    ```bash
    oc image serve --dir=./${OCP_VER}/release/ --tls-crt=./registry.crt --tls-key=./registry.key &
    ```

16. Deploy the cluster

    ```
    openshift-install create cluster --dir ./${OCP_VER}/config
    ```
#
### Cluster Access

You can now access the cluster via CLI with oc or the web console with a web browser.

1. Locate the OpenShift access information provided by the final installer output.

    Example:
    ```
    INFO Waiting up to 10m0s for the openshift-console route to be created... 
    INFO Install complete!                            
    INFO To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/home/ec2-user/data/vid-pres/${OCP_VER}/config/auth/kubeconfig' 
    INFO Access the OpenShift web-console here: https://console-openshift-console.apps.test-cluster.testocp1.net 
    INFO Login to the console with user: "kubeadmin", and password: "z9yDP-2M6DS-oE9Im-Dcdzk" 
    INFO Time elapsed: 48m34s    
    ```

2. Set the default kube context used by oc and kubectl:  

    Example:
    ```
    export KUBECONFIG=/home/ec2-user/data/vid-pres/4.7.0/config/auth/kubeconfig
    ```

    _Config file optionaly availible at `$OCP_VER/config/auth`_

3. Access the web console:

    URL Example:
    `https://console-openshift-console.apps.test-cluster.testocp1.net`

    Credentials Example:  
    ```
    INFO Login to the console with user: "kubeadmin", and password: "z9yDP-2M6DS-oE9Im-Dcdzk
    ```
