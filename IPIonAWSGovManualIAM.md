1. Download and compress the bundle on internet connected machine using the OpenShift4-mirror companion utility found [here](https://github.com/RedHatGov/openshift4-mirror)
   
   Prereqs:
   This guide 
   You will first need to retrieve a pull secret and enter it into the literals of the value for `--pull-secret` in the command below. Pull secrets can be obtained from https://cloud.redhat.com/openshift/install/aws/installer-provisioned

    ```
    podman run -it --security-opt label=disable -v ./:/app/bundle quay.io/redhatgov/openshift4_mirror:latest \
      ./openshift_mirror bundle \
      --openshift-version 4.6.3 \
      --platform aws \
      --skip-existing \
      --skip-catalogs \
      --pull-secret '{"auths":{"cloud.openshift.com":{"auth":"b3Blb...' && \
    git clone https://github.com/RedHatGov/ocp-disconnected-docs.git ./4.6.3/ocp-disconnected && \
    rm -f ./4.6.3/rhcos/rhcos-aws.x86_64.vmdk.gz && \
    curl https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/4.6.1/rhcos-4.6.1-x86_64-aws.x86_64.vmdk.gz -o ./4.6.3/rhcos/rhcos-4.6.1-x86_64-aws.x86_64.vmdk.gz && \
    tar -zcvf openshift-4-6-3.tar.gz 4.6.3
    ```
2. Transfer bundle from internet connected machine to disconnected vpc host.

3. Extract bundle on disconnected vpc host.
    ```    
    tar -xzvf openshift-4-6-3.tar.gz
    ```

4. Create S3 Bucket and attach policies.

    ```
    export awsreg=$(aws configure get region)
    export s3name=$(date +%s"-rhcos")
    aws s3api create-bucket --bucket ${s3name} --region ${awsreg} --create-bucket-configuration LocationConstraint=${awsreg}
    aws iam create-role --role-name vmimport --assume-role-policy-document "file://4.6.3/ocp-disconnected/aws-gov-ipi-dis-maniam/trust-policy.json"
    envsubst < ./4.6.3/ocp-disconnected/aws-gov-ipi-dis-maniam/role-policy-templ.json > ./4.6.3/ocp-disconnected/aws-gov-ipi-dis-maniam/role-policy.json
    aws iam put-role-policy --role-name vmimport --policy-name vmimport --policy-document "file://4.6.3/ocp-disconnected/aws-gov-ipi-dis-maniam/role-policy.json"
    ```

5. Upload RHCOS Image to S3

    ```
    gzip -d ./4.6.3/rhcos/rhcos-4.6.1-x86_64-aws.x86_64.vmdk.gz
    aws s3 mv ./4.6.3/rhcos/rhcos-4.6.1-x86_64-aws.x86_64.vmdk s3://${s3name}
    ```

6. Create AMI

    ```
    envsubst < ./4.6.3/ocp-disconnected/aws-gov-ipi-dis-maniam/containers-templ.json > ./4.6.3/ocp-disconnected/containers.json
    taskid=$(aws ec2 import-snapshot --region ${awsreg} --description "rhcos-snapshot" --disk-container file://4.6.3/ocp-disconnected/containers.json | jq -r '.ImportTaskId')
    until [[ $resp == "completed" ]]; do sleep 2; echo "Snapshot progress: "$(aws ec2 describe-import-snapshot-tasks --region ${awsreg} | jq --arg task "$taskid" -r '.ImportSnapshotTasks[] | select(.ImportTaskId==$task) | .SnapshotTaskDetail.Progress')"%"; resp=$(aws ec2 describe-import-snapshot-tasks --region ${awsreg} | jq --arg task "$taskid" -r '.ImportSnapshotTasks[] | select(.ImportTaskId==$task) | .SnapshotTaskDetail.Status'); done
    snapid=$(aws ec2 describe-import-snapshot-tasks --region ${awsreg} | jq --arg task "$taskid" '.ImportSnapshotTasks[] | select(.ImportTaskId==$task) | .SnapshotTaskDetail.SnapshotId')
    aws ec2 register-image \
      --region ${awsreg} \
      --architecture x86_64 \
      --description "rhcos-4.6.1-x86_64-aws.x86_64" \
      --ena-support \
      --name "rhcos-4.6.1-x86_64-aws.x86_64" \
      --virtualization-type hvm \
      --root-device-name '/dev/xvda' \
      --block-device-mappings 'DeviceName=/dev/xvda,Ebs={DeleteOnTermination=true,SnapshotId='${snapid}'}' 
    ```

7. Record the AMI ID from the output of the above command.



8. Create registry cert on disconnected vpc host
    ```
    export SUBJ="/C=US/ST=Virginia/O=Red Hat/CN=${HOSTNAME}"
    openssl req -newkey rsa:4096 -nodes -sha256 -keyout registry.key -x509 -days 365 -out registry.crt -subj "$SUBJ"
    ```    

9. Make a copy of the install config
    ```
    mkdir ./4.6.3//config
    cp ./4.6.3/ocp-disconnected/aws-gov-ipi-dis-maniam/install-config-template.yaml ./4.6.3/config/install-config.yaml
    ```
10. Edit install config
    For this step, Open `./4.6.3/config/install-config.yaml` and edit the following fields:

    ```
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
    ```
    cp -R ./4.6.3/config/ ./4.6.3/config.bak
    ```

12. Create manifests from install config.
    ```
    openshift-install create manifests --dir ./4.6.3/config
    ```

13. Delete the installer generated secret
    ```
    rm ./4.6.3/config/openshift/99_cloud-creds-secret.yaml 
    ```
14. create iam users and Policies

    ```
    cd ./4.6.3/ocp-disconnected/aws-gov-ipi-dis-maniam
    chmod +x ./ocp-users.sh
    ./ocp-users.sh prepPolicies
    ./ocp-users.sh createUsers
    ```

15. Use the convenience script to create the aws credentials and kubernetes secrets:
    ```
    cd ./4.6.3/ocp-disconnected/aws-gov-ipi-dis-maniam
    chmod +x ./secret-helper.sh
    ./secret-helper.sh
    cp secrets/* ../../config/openshift/
    cd -
    ```

16. start up the registry in the background
    ```
    oc image serve --dir=./4.6.3/release/ --tls-crt=./registry.crt --tls-key=./registry.key &
    ```

17. Deploy the cluster

    ```
    openshift-install create cluster --dir ./4.6.3/config
    ```