# AWS IPI Terraform

Provisions neccessary resources to begin airgapped bundle installations through isolated VPC via public VPC peering connection.

[![asciicast](https://asciinema.org/a/7WK0adg1J9Q5rcqqdKJOpGt3t.svg)](https://asciinema.org/a/7WK0adg1J9Q5rcqqdKJOpGt3t)

Current applicable overlays include openshift4_mirror bundler. 

Prereq
Local machine with terraform installed as well as either AWS credentials configured with awscli, or credentials placed in `00-auth.tf`.

Steps

# Provision AWS Resources
1. Run `terraform init` and `terraform apply`
2. Note output values, inclduing public IP

# Low-side Pull 
1. Login to bastion.
2. Register bastion with Red Hat `sudo subscription-manager register`
3. Install podman & git `sudo dnf install podman git -y`
4. Define PULL_SECRET `PULL_SECRET=''` 
5. Define OCP_VER `OCP_VER=$(curl http://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/release.txt 2>&1 | grep -oP "(?<=Version:\s\s).*")`
6. Bundle images
```bash
podman run -it --security-opt label=disable -v ./:/app/bundle quay.io/redhatgov/openshift4_mirror:latest \
      ./openshift_mirror bundle \
      --openshift-version ${OCP_VER} \
      --platform aws \
      --skip-existing \
      --skip-catalogs \
      --pull-secret ${PULL_SECRET}
```
7. Bundle repository `git clone https://github.com/redhat-cop/ocp-disconnected-docs.git ./${OCP_VER}/ocp-disconnected`

# Transfer Bundle
Tar, move, copy, rsync, airgap walk. Bundle Transfer. This example will rsync.

1. Generate ssh key on bastion `ssh-keygen`
2. Uncomment the private instance in ec2.tf
3. Uncomment and paste the contents of `~/.ssh/id_rsa.pub` in the public_key.tf's bastion_key resource
4. Uncomment the output of private instance's address
5. Run `terraform apply`
6. Note the private instance's DNS name
7. Confirm access to private bastion access via ssh ec2-user@private-bastion-address. (It may take a minute to initialize)
8. Sync the bundle `rsync -azvP ${OCP_VER} private-bastion-address:~`

# High-side Deploy
Prepare deployment.
1. Login to the private instance `ssh private-bastion-address`
2. Define version context `export OCP_VER=4.8.4`
3. Prepare config directory `mkdir ./${OCP_VER}/config`
4. Prepare registry cert
```bash
export SUBJ="/C=US/ST=Virginia/O=Red Hat/CN=${HOSTNAME}"
    openssl req -newkey rsa:4096 -nodes -sha256 -keyout registry.key -x509 -days 365 -out registry.crt -subj "$SUBJ" -addext "subjectAltName = DNS:$HOSTNAME"
```
5. Adjust the `example-config.yaml` with the proper values, replacing the subnets and mirror location with previous outputs and the registry cert from `registry.crt`'s contents.
6. Rename it `install-config.yaml` and place it in `./${OCP_VER}/config/install-config.yaml`
```bash
cat > ./${OCP_VER}/config/install-config.yaml
paste
^d
```
7. Copy binaries to a PATH directory `sudo cp ./${OCP_VER}/bin/* /usr/bin`

# Install OpenShift 4
Install OpenShift 4
1. Serve images `oc image serve --dir=./${OCP_VER}/release/ --tls-crt=./registry.crt --tls-key=./registry.key &`
2. Run the installer `openshift-install create cluster --dir ./${OCP_VER}/config --log-level=debug`


