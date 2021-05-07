## Deploying a Disconnected Registry for OpenShift 4 on Standalone Non-production Quay
To install OpenShift 4 in a disconnected environment, you must provide a registry server to host the images for the installation.  This process is documented in the OpensShift documentation section [Creating a mirror registry for installation in a restricted network](https://docs.openshift.com/container-platform/4.7/installing/install_config/installing-restricted-networks-preparations.html).  The registry must adhere to the most recent container image API, referred to as `schema2`, see [About the mirror registry](https://docs.openshift.com/container-platform/4.7/installing/install_config/installing-restricted-networks-preparations.html#installation-about-mirror-registry_installing-restricted-networks-preparations).  OpenShift documentation of the disconnected mirroring process uses the [Docker registery container](https://hub.docker.com/_/registry).  However, in some cases a customer may wish to only use packages provided by Red Hat.  Red Hat Quay can be installed in a standalone non-production configuration to support installing OpenShift.

### Requirements
* An internet connected host with podman installed
* A login for registry.redhat.io (Red Hat customer login)
* Enough free disk space for the release images.  OpenShift 4.7 images are approximately 7GB.

### Detailed Steps
1. Set default location for Quay installation
    ```
    export QUAY=/path/to/quay
    ```
2. Setup Postgresql

    a.  Configure postgresql data directory

    ```
    mkdir $QUAY/postgresql-quay
    sudo setfacl -m u:26:-wx $QUAY/postgresql-quay
    ```

    b.  Start postgresql container, set POSTGRESQL variables as desired

    ```
    sudo podman run -d --name postgresql-quay -e POSTGRESQL_USER=quayuser \
        -e POSTGRESQL_PASSWORD=quaypass -e POSTGRESQL_DATABASE=quay -e \    
        POSTGRESQL_ADMIN_PASSWORD=adminpass -p 5432:5432 \
        -v $QUAY/postgres-quay:/var/lib/pgsql/data:Z \ 
        registry.redhat.io/rhel8/postgresql-10:1
    ```

    c.  Configure postgresql

    ```
    sudo podman exec -it postgresql-quay \
    /bin/bash -c 'echo "CREATE EXTENSION IF NOT EXISTS pg_trgm" | \
    psql -d quay -U postgres'
    ```

3. Setup Redis

    Start redis container, set REDIS_PASSWORD as desired
    ```
    sudo podman run -d --name redis -p 6379:6379 \
    -e REDIS_PASSWORD=strongpassword registry.redhat.io/rhel8/redis-5:1
    ```

4.  Generate Quay certificate
    * Update fqdn and ip address for registry host
    ```
    cat > ssl-ca.cnf <<EOF
    [req]
    default_bits  = 4096
    distinguished_name = req_distinguished_name
    req_extensions = req_ext
    x509_extensions = v3_req
    prompt = no

    [req_distinguished_name]
    countryName = US
    stateOrProvinceName = NC
    localityName = Raleigh
    organizationName = Red Hat
    commonName = localhost

    [req_ext]
    subjectAltName = @alt_names

    [v3_req]
    subjectAltName = @alt_names

    # Key usage: this is typical for a CA certificate. However since it will
    # prevent it being used as an test self-signed certificate it is best
    # left out by default.
    # keyUsage                = critical,keyCertSign,cRLSign

    basicConstraints        = critical,CA:true
    subjectKeyIdentifier    = hash

    [alt_names]
    DNS.1 = localhost
    DNS.2 = fqdn
    IP.1 = 1.2.3.4
    EOF

    openssl req -newkey rsa:4096 -nodes -sha256 -keyout domain.key -x509 -days 365 -out domain.crt -config ssl-ca.cnf
    ```

5.  Setup Quay

    a. Start quay configuration container.  The last parameter here is the _*quayconfig*_ user password.  Use whatever value you wish here.
        
    ```
    sudo podman run -it --name quay_config -p 8080:8080 \ registry.redhat.io/quay/quay-rhel8:v3.4.3 config secret
    ```

    b. Configure quay

    After starting the Quay config container, access the config web ui on the host running the container, for example http://localhost:8080 (or substitute localhost with the host system).  When prompted for authentication, use _*quayconfig*_ and _*secret*_ (or the whatever value was used in the previous step) for the credentials.

    The minimum required changes are:

    *Server Configuration*
    - Server Configuration:  <hostname of container host>:<port>   (port required if not 80 or 443)
    - TLS:   Red Hat Quay handles TLS, Browse and select cert and key created in Step 5 

    *Database*
    - Database Type:  Postgres
    - Database Server:  <hostname of container host>:<port>  (port from step 2b)  
      _NOTE:_  In some cases, Quay may have issues talking to Postgres using the container host  IP.  In this case, use the IP assigned to the Postgres container (i.e. 10.88.0.x).
    - Username:  from Step 2b
    - Password:  from Step 2b
    - Database Name:  from Step 2b

    *Redis*
    - Redis Hostname:  <hostname of container host>  
      _NOTE:_  In some cases, Quay may have issues talking to Redis using the container host  IP.  In this case, use the IP assigned to the Redis container (i.e. 10.88.0.x).
    - Redis port:  from Step 4a
    - Redis password:  from Step 4a

    *Access Settings*
    - Super Users:  add a user here that will be a Super User, click Add


    If all required settings have been configured correctly, click the Validate
    *Configuration Changes* button at the bottom of the page.  

    If everything is correct, click the Download button to save the configuration.  

    Hit Ctrl-C to stop the quay_config container.  

    c. Configure quay directories
    ```
    mkdir $QUAY/config
    mkdir $QUAY/storage
    setfacl -m u:1001:-wx $QUAY/storage
    tar xvf <download_dir>/quay-config.tar.gz -C $QUAY/config
    ```

    d. Start quay container
    ```
    sudo podman run -d -p 8080:8080 --name=quay -v $QUAY/config:/conf/stack:Z \ 
    -v $QUAY/storage:/datastorage:Z registry.redhat.io/quay/quay-rhel8:v3.4.3
    ```

    The quay container will take a couple of minutes to start up fully.  Once done, you can access Quay at  https://<hostname>:<port> as defined in Step 6b.  

    For the initial login, click Create Account, and create an account matching the name specified as a Super User in Step 6b.  

6.  Configure Quay repository for OpenShift images
    - Create New Organization to create a new organization to host the OpenShift release images.
    - Click Create New Repository to create a repository to host the OpenShift release images.
    - These names will be used in the next step.
  
  
7.  Mirror OpenShift image to disconnected disk on internet connected host
    ```
    EMAIL=youremail@example.com
    OCP_RELEASE=4.7.3
    LOCAL_REGISTRY='quay.local.lab:8443'
    LOCAL_REPOSITORY='ocp4/openshift4'
    PRODUCT_REPO='openshift-release-dev'
    RELEASE_NAME='ocp-release'
    ARCHITECTURE='x86_64'
    REMOVABLE_MEDIA_PATH=/home/mike/bundle

    LOCAL_SECRET_TXT=pull-secret.txt
    LOCAL_SECRET_JSON='pull-secret.json'

    # use the credentials for the account created in Step 6d.
    REGISTRY_CREDS=$(echo -n '<quay_user>:<quay_pass>' | base64 -w0)
    jq ".auths += {\"${LOCAL_REGISTRY}\": {\"auth\": \"${REGISTRY_CREDS}\",\"email\": \"${EMAIL}\"}}" < ${LOCAL_SECRET_TXT} > ${LOCAL_SECRET_JSON}

    # this will print the info (imageContentSources) needed to put in install-config.yaml which won't get printed syncing to local directory
    oc adm release mirror -a ${LOCAL_SECRET_JSON} --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-${ARCHITECTURE} --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-${ARCHITECTURE} --dry-run
        
    # sync to local directory
    oc adm release mirror -a ${LOCAL_SECRET_JSON} --to-dir=${REMOVABLE_MEDIA_PATH}/mirror quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-${ARCHITECTURE}
    
    tar cvf openshift-${OCP_RELEASE}-release-bundle.tar.gz ${REMOVABLE_MEDIA_PATH}
    ```

8.  Transfer the tar file openshift-${OCP_LEASE}-release-bundle.tar.gz to the disconnected registry host.

9.  Extract the release bundle.  This _*MUST*_ be extracted to the same path as ${REMOVABLE_MEDIA_PATH} in Step 7.  If you used an absolute path in Step 7, this will work automatically.
    ```
    tar xvf /path/to/openshift-${OCP_RELEASE}-release-bundle.tar.gz
    ```

10. Mirror the release images to your disconnected registry
    ```
    # mirror images from directory to quay, --insecure shouldn't be needed if quay has a valid cert
    oc image mirror -a ${LOCAL_SECRET_JSON} --from-dir=${REMOVABLE_MEDIA_PATH}/mirror "file://openshift/release:${OCP_RELEASE}*" ${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}
    ```


