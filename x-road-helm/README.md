# Helm charts for X-Road Security Server cluster

This repository contains unofficial Helm charts for installing an X-Road Security Server cluster on Kubernetes. These charts are considered a proof of concept. In case a more complex and secure setup is required, it is recommended to create your own Helm charts using the charts in this repository as an example.

Currently published Security Server Docker images have some issues requiring fixes and workarounds, necessitating thorough testing before deploying a Security Server cluster to a production environment.

For additional clarity it should be mentioned that despite the official naming "Security Server Sidecar" does not follow Kubernetes "sidecar" conventions when running as a cluster.

By default, Helm charts install images with Estonian country-specific configuration.

## Additional reading

Official Security Server Sidecar images: https://hub.docker.com/r/niis/xroad-security-server-sidecar

Official user guide for Security Server Sidecar on kubernetes: https://github.com/nordic-institute/X-Road/blob/develop/doc/Sidecar/kubernetes_security_server_sidecar_user_guide.md

Official security guide for Security Server Sidecar on kubernetes: https://github.com/nordic-institute/X-Road/blob/develop/doc/Sidecar/kubernetes_security_guide.md

Zalando Postgres operator documentation: https://postgres-operator.readthedocs.io/en/latest/

## Issues with official docker images

**Missing features and complexities:**
* The sidecar image currently lacks the xroad-addon-hwtokens package, which may be necessary for EE instances.
* Updating CA certificates for global configuration loaded over HTTPS is not straightforward.
* Autologin only supports soft tokens, requiring manual input for HSM token PINs. This is especially problematic for secondary servers that may restart due to liveness issues.
* All admins must use the same credentials for the admin interface, and roles cannot be used to grant partial access.
* External database configuration is limited, and database initialization assumes a "postgres" user.

**Possible solutions:**

Creating a custom entrypoint script to handle additional setup:
* Install required packages such as xroad-addon-hwtokens.
* Update CA certificates for loading global configuration.
* Implement custom autologin for entering HSM token PINs.
* Add admin users to the container or configure it to use a remote system for authentication and authorization.

**Additional considerations:**

Proper load balancing may be challenging depending on the Kubernetes service provider. For example, Estonian "Riigipilv" does not provide a BGP (Border Gateway Protocol) load balancer and does not support MetalLB in layer 2 mode. Because of this, a simple DNS round robin solution may lead to partial service outages when load balancer nodes undergo maintenance.

## System requirements

Each Security Server container can use up to 4GB of RAM. Therefore, a cluster with one primary and two secondary servers could potentially consume 12GB of RAM under heavy load. Remember that Kubernetes might start additional containers during updates. In addition to the servers, the PostgreSQL database and Kubernetes itself require memory. However, Kubernetes efficiently manages memory, so actual usage might be lower than expected. For a setup with only the Security Server cluster and its database on three Kubernetes worker nodes, 8GB per node should suffice for normal operations and maintenance.

Regarding CPU requirements, 4 cores per Kubernetes worker node should be adequate.

In this calculation, it is assumed that the Kubernetes control plane runs on separate dedicated nodes.

## PostgreSQL

A production-ready solution should utilize a clustered database. In Kubernetes, one can use, for example, the Zalando Postgres operator. Any other alternative should work as well.

An access to S3 storage is a prerequisite to be able to create database backups.

A proper PostgreSQL cluster installation, configuration and securing is out of the scope of the current document, and only a simplified guide is provided.

Depending on the Kubernetes service provider Postgres operator may already be installed and configured. In case Postgres operator is not yet installed it can be done with the following commands:
```bash
helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator
# Use provided example "values" files, or create new appropriate ones
helm upgrade postgres-operator postgres-operator-charts/postgres-operator --install --create-namespace -n postgres-operator -f postgres-operator-values.yaml
helm repo add postgres-operator-ui-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui
helm upgrade postgres-operator-ui postgres-operator-ui-charts/postgres-operator-ui --install -n postgres-operator -f postgres-operator-ui-values.yaml
```

To install a PostgreSQL cluster, create an appropriate "values" file based on the provided example and execute the command:
```bash
helm upgrade --install -n xtee xrd-pgop helm/pgop -f pgop-values-example.yaml
```

By default, the Zalando operator assumes that the S3 bucket is defined in the operator's configuration and all clusters use this bucket for backups. This works best when the Kubernetes cluster contains services of a single project and there is no risk of unauthorized access to another project's backup data. In this scenario, the operator automatically sets the WAL_BUCKET_SCOPE_SUFFIX variable to the PostgreSQL object's UID. If this cluster is deleted and recreated, the UID changes, and the backups are stored in a different S3 bucket folder. To restore in this case, the parameter "clone.uid" must be added, and the restored database will also have a new UID, allowing for multiple restorations of the previous state if necessary.

Alternatively, WAL_S3_BUCKET can be set individually for each cluster, but in this case, the operator no longer allows using the UID in backup paths. With this option, great care must be taken during restoration, as an incorrectly configured restoration manifest could overwrite the old backup folder.

The following commands may be used to create a manual backup:
```bash
kubectl -n xtee exec -it xrd-pgop-0 -- bash
su - postgres
envdir "/run/etc/wal-e.d/env" /scripts/postgres_backup.sh "/home/postgres/pgdata/pgroot/data"
# Verify that the backup was successful
envdir "/run/etc/wal-e.d/env" wal-g backup-list
```

Database parameters changes are applied with the help of `patronictl`:
```bash
kubectl -n xtee exec -it xrd-pgop-0 -- patronictl edit-config
```

Volumes used by database may be extended using the following commands:
```bash
kubectl patch pvc pgdata-xrd-pgop-0 -p '{"spec":{"resources":{"requests":{"storage":"2000Mi"}}}}'
kubectl patch pvc pgdata-xrd-pgop-1 -p '{"spec":{"resources":{"requests":{"storage":"2000Mi"}}}}'
kubectl patch pvc pgdata-xrd-pgop-2 -p '{"spec":{"resources":{"requests":{"storage":"2000Mi"}}}}'
```

## Installation of X-Road Security Server cluster

Primary Security Server does not participate in X-Road message exchange by default, because the Security Server container consists of several services, and the kubernetes liveness check is not flexible enough to detect the readiness of separate admin port and X-Road message exchange. If we take the availability of the admin interface (port 4000) as a basis, then its liveness does not guarantee that the Security Server is initialized and is ready for X-Road message exchange. However, if port 5588 is used to check the liveness of the Security Server, then in case of problems, Kubernetes will also terminate access to the admin interface. As a result, if port 5588 does not respond, it is also not possible to fix the problem using the admin interface.

Before Security Server installation, it is necessary to deploy the database that will be used by the Security Server containers. Since the database must be shared between all nodes of the Security Server cluster, an internal database cannot be used.

Security Server cluster is using three types of secrets that can be passed to Kubernetes via a "values" file, or managed separately from the Helm chart, referenced by secret name in Helm "values" files. It is advised to use separate secrets because Helm "values" files are stored in Kubernetes as plain text and do not provide strong security.

**Database credentials**

Contains field: `password`. Helm "values" must contain either a reference to the secret name `dbSecretName` or values in the dictionary `dbSecret`. When Zalando Postgres operator is used, `dbSecretName` should point to the secret generated by operator. For example `postgres.xrd-pgop.credentials.postgresql.acid.zalan.do`.

**Security Server secrets**

Environmental variables containing secrets required by the Security Server. Consists of fields: `XROAD_ADMIN_PASSWORD`, `XROAD_ADMIN_USER` and `XROAD_TOKEN_PIN`. Helm "values" must contain either a reference to the secret name `envSecretName` or values in the dictionary `envSecret`.

Secret can be created with the following command (make sure to replace with proper credentials):
```bash
kubectl -n xtee apply -f xrd-env-secret-example.yaml
```

**SSH secrets**

SSH keys are required for configuration replication from primary Security Server to secondaries. Consists of fields: `private-key` and `public-key`. Helm "values" must contain either a reference to the secret name `sshSecretName` or values in the dictionary `sshSecret`.

Secret can be created with the following command (make sure to replace with proper keys):
```bash
kubectl -n xtee apply -f xrd-ssh-secret-example.yaml
```

**Security Server installation**

To install a Security Server cluster, create an appropriate "values" file based on the provided example and execute the command:
```bash
helm upgrade --install -n xtee xrd-security-server helm/security-server -f security-server-values-example.yaml
```

Primary Security Server logs can be viewed with a command:
```bash
kubectl -n xtee logs --tail=10 -f xrd-security-server-primary-0
```

Once the primary server has started, the admin interface port can be forwarded, and then the UI can be accessed at URL https://localhost:4000.
```bash
kubectl -n xtee port-forward svc/xrd-security-server-admin 4000:4000
```

The Security Server needs to be initialized and configured using the admin interface. If a backup file is used for initialization, please refer to the "Security Server backup" chapter for specific instructions.

If the Security Server configuration needs to be modified, enter the container and change the `local.ini` file:
```bash
kubectl -n xtee exec -it -c security-server xrd-security-server-primary-0 -- bash
nano-tiny /etc/xroad/conf.d/local.ini
```

To apply configuration changes it is sufficient to restart services inside the container. For example proxy service configurations are applied with the command:
```bash
kubectl -n xtee exec -it -c security-server xrd-security-server-primary-0 -- bash
supervisorctl restart xroad-proxy
```

Once the primary Security Server is configured, secondary servers should be able to start. Secondary server logs can be viewed with a command:
```bash
kubectl -n xtee logs --tail=10 -f -l app.kubernetes.io/component=secondary --prefix --all-containers
```

In order to test whether secondary Security Server nodes are able to send X-Road queries, it is possible to forward the consumer port and execute a query (make sure to use the correct X-Road identifiers and if necessary add client certificates to the `curl` query):
```bash
# In the first terminal
kubectl -n xtee port-forward svc/xrd-security-server-consumer 8443:443
# In the second terminal
curl -i -k -H "accept: application/json" -H "X-Road-Client:ee-dev/GOV/70006317/k8s" "https://localhost:8443/r1/ee-dev/GOV/70006317/xroad-center/listMethods"
```

**Configuring load balancer**

The exact configuration for a load balancer is out of the scope of this guide, and only general advice is given.

For the best results, use an external load balancer and define Kubernetes services of type LoadBalancer (use the parameter `serviceType` in the Helm "values" file). If the Kubernetes service provider does not support the LoadBalancer service type, then it is possible to publish a service using the Kubernetes NodePort type and configure an external proxy to accept connections and forward them to Kubernetes Node ports.

## Security Server backup

The Security Server can encrypt backup files using GPG. To ensure that you can decrypt these backups even if the server is lost, you need to manually copy the /etc/xroad/gpghome directory to a secure location (this directory is not included in the Security Server's backup).

It's recommended to back up the GPG directory even if encryption is not enabled.

**Backing up the GPG directory**

To back up the gpghome directory, navigate to the container and execute the following command:

```bash
kubectl -n xtee exec -c security-server xrd-security-server-primary-0 -- tar czf - --exclude=S.* /etc/xroad/gpghome > ./xrd-gpghome.tgz
```

**Restoring the GPG directory**

To restore the gpghome directory from the backup, run this command:

```bash
cat xrd-gpghome.tgz | kubectl -n xtee exec -i -c security-server xrd-security-server-primary-0 -- tar xzf - -C /
```

**Decrypting the backup on another machine**

On a different machine, you can decrypt the archive using the following command (ensure that gpghome points to the correct location of your GPG files):

```bash
gpg --homedir gpghome --output conf_backup_20240523-133743.tar --decrypt conf_backup_20240523-133743.gpg
```

**Restoring the backup on the Security Server**

It is possible to restore backups via the admin UI, but it requires the Security Server to be initialized, which is often not the case when performing disaster recovery. Instead of initializing the Security Server with the same identifier, restoring the GPG directory, and using the UI to restore the configuration, it might be more convenient to perform all steps using the command line.

To restore the backup on the Security Server from the command line, first restore the contents of the /etc/xroad/gpghome directory within the container. Then, add the backup file and run the "restore" command (replace the backup file name and path, as well as the Security Server identifier, with the correct values):

```
kubectl -n xtee cp -c security-server ~/Downloads/conf_backup_20240523-133743.gpg xrd-security-server-primary-0:/var/lib/xroad/backup/
kubectl -n xtee exec -c security-server xrd-security-server-primary-0 -- sudo -iu xroad /usr/share/xroad/scripts/restore_xroad_proxy_configuration.sh -s ee-dev/GOV/70006317/k8s -f /var/lib/xroad/backup/conf_backup_20240523-133743.gpg
```

## Security Server upgrade

**Scaling down before upgrading**

Since each new version of the Security Server may introduce database changes, the safest upgrade strategy is to first scale down the primary stateful set and secondary deployment to zero, essentially stopping all pods:

```bash
kubectl -n xtee scale --replicas=0 deploy/xrd-security-server-secondary
kubectl -n xtee scale --replicas=0 statefulset/xrd-security-server-primary
```

**Upgrading PostgreSQL**

If the new Security Server version uses a newer PostgreSQL version, it's wise to upgrade PostgreSQL now while the Security Servers are down.

The upgrade process depends on the chosen PostgreSQL variant. The following commands demonstrate how to upgrade using the Zalando Postgres Operator with an S3 backup. Note: This solution might not be the safest as the existing cluster is removed beforehand. For production environments, creating a new DB cluster from backup and updating the Security Server configuration to point to the new DB cluster might be preferable.

Update Helm "values" file and set `postgresql.version` to the appropriate value.

```bash
# Ensuring that all changes have been backed up before we stop the database.
kubectl -n xtee exec -it xrd-pgop-0 -- bash
su - postgres
envdir "/run/etc/wal-e.d/env" /scripts/postgres_backup.sh "/home/postgres/pgdata/pgroot/data"
# Making sure that the backup was successful.
envdir "/run/etc/wal-e.d/env" wal-g backup-list
# Exiting container
exit
exit

# Removing old DB cluster
helm -n xtee uninstall xrd-pgop

# Checking whether all DB pods have stopped before installing the new version.
kubectl -n xtee get po

# Deploying new DB cluster
helm upgrade --install -n xtee xrd-pgop helm/pgop -f pgop-values-new-version.yaml

# DB logs
kubectl -n xtee logs --tail=10 -f -l cluster-name=xrd-pgop --prefix --all-containers
```

It's also possible to perform an in-place upgrade of PostgreSQL according to the documentation, but this requires thorough testing:
```bash
kubectl -n xtee exec -it xrd-pgop-0 -- bash
su postgres
python3 /scripts/inplace_upgrade.py 3
``` 

**Upgrading Security Server cluster**

Use a newer version of Helm charts or update the software version fields `primaryTag` and `secondaryTag` in the Helm "values" file and run the Helm upgrade command:
```bash
helm upgrade --install -n xtee xrd-security-server helm/security-server -f security-server-values-new-version.yaml
```
