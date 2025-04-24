

### Key Concepts Explained

#### 1. **Secret**
A **Secret** in Kubernetes/OpenShift is used to store sensitive information, such as passwords, credentials, or API keys, in an encoded format (base64). In this lab, a secret named `world-cred` is created to store database credentials (`user`, `password`, `database`) for the MySQL database.

- **Purpose**: Secrets securely pass sensitive data to applications without hardcoding them in the application code or configuration files.
- **Lab Usage**: The `world-cred` secret provides the MySQL credentials (`user: redhat`, `password: redhat123`, `database: world_x`) to the `dbserver` deployment via environment variables.
- **Command**:
  ```bash
  oc create secret generic world-cred \
    --from-literal user=redhat \
    --from-literal password=redhat123 \
    --from-literal database=world_x
  ```
- **YAML Representation**:
  ```yaml
  apiVersion: v1
  kind: Secret
  metadata:
    name: world-cred
    namespace: storage-review
  type: Opaque
  data:
    user: cmVkaGF0
    password: cmVkaGF0MTIz
    database: d29ybGRfeA==
  ```
  - `data`: Contains base64-encoded values of the credentials.
  - `type: Opaque`: Indicates a generic secret (not tied to a specific type like TLS or Docker credentials).

#### 2. **ConfigMap**
A **ConfigMap** is used to store non-sensitive configuration data, such as configuration files, environment variables, or command-line arguments, that can be consumed by pods.

- **Purpose**: ConfigMaps decouple configuration from application code, enabling easier updates without rebuilding container images.
- **Lab Usage**: A ConfigMap named `dbfiles` is created from the `insertdata.sql` file and mounted as a volume in the `file-sharing` deployment to provide an SQL script for database initialization.
- **Command**:
  ```bash
  oc create configmap dbfiles \
    --from-file ~/DO180/labs/storage-review/insertdata.sql
  ```
- **YAML Representation**:
  ```yaml
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: dbfiles
    namespace: storage-review
  data:
    insertdata.sql: |
      -- MySQL dump 10.13  Distrib 8.0.19, for osx10.14 (x86_64)
      --
      -- Host: 127.0.0.1    Database: world_x
      -- ------------------------------------------------------
      -- Server version 8.0.19-debug
      ... (content of insertdata.sql)
  ```
  - `data`: Stores the content of the `insertdata.sql` file as a key-value pair.

#### 3. **Deployment**
A **Deployment** manages a set of pods, ensuring the desired number of replicas are running and handling updates (e.g., rolling updates). It uses a **Pod Template** to define the pod’s specification.

- **Purpose**: Deployments provide scalability, self-healing, and rolling updates for stateless applications.
- **Lab Usage**:
  - **dbserver**: A MySQL database deployment using the `mysql-app:v1` image.
  - **file-sharing**: A PHP web application deployment using the `php-webapp-mysql:v1` image, scaled to two replicas.
- **Commands**:
  - For `dbserver`:
    ```bash
    oc create deployment dbserver \
      --image registry.ocp4.example.com:8443/redhattraining/mysql-app:v1
    ```
  - For `file-sharing`:
    ```bash
    oc create deployment file-sharing \
      --image registry.ocp4.example.com:8443/redhattraining/php-webapp-mysql:v1
    oc scale deployment file-sharing --replicas 2
    ```
- **YAML Representation (dbserver)**:
  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: dbserver
    namespace: storage-review
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: dbserver
    template:
      metadata:
        labels:
          app: dbserver
      spec:
        containers:
        - name: dbserver
          image: registry.ocp4.example.com:8443/redhattraining/mysql-app:v1
          env:
          - name: MYSQL_USER
            valueFrom:
              secretKeyRef:
                name: world-cred
                key: user
          - name: MYSQL_PASSWORD
            valueFrom:
              secretKeyRef:
                name: world-cred
                key: password
          - name: MYSQL_DATABASE
            valueFrom:
              secretKeyRef:
                name: world-cred
                key: database
  ```
- **YAML Representation (file-sharing)**:
  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: file-sharing
    namespace: storage-review
  spec:
    replicas: 2
    selector:
      matchLabels:
        app: file-sharing
    template:
      metadata:
        labels:
          app: file-sharing
      spec:
        containers:
        - name: file-sharing
          image: registry.ocp4.example.com:8443/redhattraining/php-webapp-mysql:v1
  ```

#### 4. **PersistentVolumeClaim (PVC)**
A **PersistentVolumeClaim (PVC)** is a request for storage by a user. It specifies the storage size, access mode, and storage class, which Kubernetes matches to a **PersistentVolume (PV)** provisioned by the cluster’s storage backend.

- **Purpose**: PVCs abstract storage provisioning, allowing pods to request storage dynamically without directly managing PVs.
- **Lab Usage**:
  - **dbserver-lvm-pvc**: Used by the `dbserver` deployment for local storage (`lvms-vg1` storage class) to store MySQL data.
  - **shared-pvc**: Used by both `file-sharing` and `dbserver` deployments for NFS storage (`nfs-storage` storage class) to share files.
- **Access Modes**:
  - **RWO (ReadWriteOnce)**: The volume can be mounted as read-write by a single node.
  - **RWX (ReadWriteMany)**: The volume can be mounted as read-write by multiple nodes (used for NFS in this lab).
- **Commands**:
  - For `dbserver-lvm-pvc`:
    ```bash
    oc set volume deployment/dbserver \
      --add --name dbserver-lvm --type persistentVolumeClaim \
      --claim-mode rwo --claim-size 1Gi --mount-path /var/lib/mysql \
      --claim-class lvms-vg1 --claim-name dbserver-lvm-pvc
    ```
  - For `shared-pvc`:
    ```bash
    oc set volume deployment/file-sharing \
      --add --name shared-volume --type persistentVolumeClaim \
      --claim-mode rwo --claim-size 1Gi --mount-path /home/sharedfiles \
      --claim-class nfs-storage --claim-name shared-pvc
    ```
- **YAML Representation (dbserver-lvm-pvc)**:
  ```yaml
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: dbserver-lvm-pvc
    namespace: storage-review
  spec:
    accessModes:
    - ReadWriteOnce
    resources:
      requests:
        storage: 1Gi
    storageClassName: lvms-vg1
  ```
- **YAML Representation (shared-pvc)**:
  ```yaml
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: shared-pvc
    namespace: storage-review
  spec:
    accessModes:
    - ReadWriteOnce
    resources:
      requests:
        storage: 1Gi
    storageClassName: nfs-storage
  ```

#### 5. **StorageClass**
A **StorageClass** defines the type of storage provisioned for PVCs, including the provisioner, parameters, and reclaim policy.

- **Purpose**: StorageClasses enable dynamic provisioning of storage based on the cluster’s storage backend (e.g., LVM, NFS).
- **Lab Usage**:
  - **lvms-vg1**: Used for local storage for the `dbserver` deployment (optimized for performance).
  - **nfs-storage**: Used for shared storage between `file-sharing` and `dbserver` deployments (supports RWX for shareability).
- **No YAML Provided**: StorageClasses are typically predefined in the cluster and not created in this lab. Example StorageClass for reference:
  ```yaml
  apiVersion: storage.k8s.io/v1
  kind: StorageClass
  metadata:
    name: nfs-storage
  provisioner: example.com/nfs
  parameters:
    server: nfs-server.example.com
    path: /exported/path
  ```

#### 6. **Service**
A **Service** provides a stable network endpoint (ClusterIP) to access a set of pods, typically selected by labels. It enables load balancing across pods.

- **Purpose**: Services abstract pod IPs, allowing communication between applications within the cluster.
- **Lab Usage**:
  - **mysql-service**: Exposes the `dbserver` deployment on port 3306 for database access.
  - **file-sharing**: Exposes the `file-sharing` deployment on port 8080 for web access.
- **Commands**:
  - For `mysql-service`:
    ```bash
    oc expose deployment dbserver --name mysql-service \
      --port 3306 --target-port 3306
    ```
  - For `file-sharing`:
    ```bash
    oc expose deployment file-sharing --name file-sharing \
      --port 8080 --target-port 8080
    ```
- **YAML Representation (mysql-service)**:
  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: mysql-service
    namespace: storage-review
  spec:
    selector:
      app: dbserver
    ports:
    - port: 3306
      targetPort: 3306
      protocol: TCP
  ```
- **YAML Representation (file-sharing)**:
  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: file-sharing
    namespace: storage-review
  spec:
    selector:
      app: file-sharing
    ports:
    - port: 8080
      targetPort: 8080
      protocol: TCP
  ```

#### 7. **Route**
A **Route** in OpenShift exposes a service to external traffic by mapping a hostname to a service, typically using an ingress controller.

- **Purpose**: Routes provide external access to applications running in the cluster.
- **Lab Usage**: A route named `file-sharing` exposes the `file-sharing` service at `http://file-sharing-storage-review.apps.ocp4.example.com` for web access.
- **Command**:
  ```bash
  oc expose service/file-sharing
  ```
- **YAML Representation**:
  ```yaml
  apiVersion: route.openshift.io/v1
  kind: Route
  metadata:
    name: file-sharing
    namespace: storage-review
  spec:
    host: file-sharing-storage-review.apps.ocp4.example.com
    to:
      kind: Service
      name: file-sharing
    port:
      targetPort: 8080
  ```

#### 8. **Volume Mount**
A **Volume** in Kubernetes/OpenShift provides storage that can be mounted into a container at a specific path. Volumes can be backed by various sources, such as PVCs, ConfigMaps, or Secrets.

- **Purpose**: Volumes allow pods to persist data, share data, or access configuration files.
- **Lab Usage**:
  - **dbserver-lvm**: A PVC-based volume mounted at `/var/lib/mysql` for MySQL data storage.
  - **config-map-pvc**: A ConfigMap-based volume (`dbfiles`) mounted at `/home/database-files` in the `file-sharing` deployment.
  - **shared-volume**: A PVC-based volume (`shared-pvc`) mounted at `/home/sharedfiles` in both `file-sharing` and `dbserver` deployments for file sharing.
- **Commands**:
  - For `dbserver-lvm`:
    ```bash
    oc set volume deployment/dbserver \
      --add --name dbserver-lvm --type persistentVolumeClaim \
      --claim-mode rwo --claim-size 1Gi --mount-path /var/lib/mysql \
      --claim-class lvms-vg1 --claim-name dbserver-lvm-pvc
    ```
  - For `config-map-pvc`:
    ```bash
    oc set volume deployment/file-sharing \
      --add --name config-map-pvc --type configmap \
      --configmap-name dbfiles \
      --mount-path /home/database-files
    ```
  - For `shared-volume` (file-sharing):
    ```bash
    oc set volume deployment/file-sharing \
      --add --name shared-volume --type persistentVolumeClaim \
      --claim-mode rwo --claim-size 1Gi --mount-path /home/sharedfiles \
      --claim-class nfs-storage --claim-name shared-pvc
    ```
  - For `shared-volume` (dbserver):
    ```bash
    oc set volume deployment/dbserver \
      --add --name shared-volume \
      --claim-name shared-pvc \
      --mount-path /home/sharedfiles
    ```

#### 9. **Scaling**
Scaling a deployment adjusts the number of pod replicas to handle increased load or ensure high availability.

- **Purpose**: Scaling ensures the application can handle varying workloads.
- **Lab Usage**: The `file-sharing` deployment is scaled to two replicas.
- **Command**:
  ```bash
  oc scale deployment file-sharing --replicas 2
  ```

---

### Storage Routes and Services Explained

#### Storage Routes
In the context of this lab, "storage routes" refers to how storage is accessed and shared between applications, facilitated by **PVCs**, **StorageClasses**, and **volume mounts**. The lab uses two distinct storage routes:

1. **Local Storage for Database (`dbserver-lvm-pvc`)**:
   - **StorageClass**: `lvms-vg1` (LVM-based local storage).
   - **Access Mode**: `ReadWriteOnce` (RWO).
   - **Purpose**: Provides high-performance storage for the MySQL database, as local storage typically has lower latency than networked storage.
   - **Mount Path**: `/var/lib/mysql` in the `dbserver` deployment.
   - **Characteristics**:
     - Optimized for single-node access.
     - Not shareable across multiple nodes (RWO).
     - Used for persistent storage of MySQL data files.

2. **NFS Storage for File Sharing (`shared-pvc`)**:
   - **StorageClass**: `nfs-storage` (NFS-based shared storage).
   - **Access Mode**: `ReadWriteOnce` (RWO, though NFS typically supports RWX).
   - **Purpose**: Enables file sharing between the `file-sharing` and `dbserver` deployments, as NFS supports shared access across multiple pods/nodes.
   - **Mount Path**: `/home/sharedfiles` in both `file-sharing` and `dbserver` deployments.
   - **Characteristics**:
     - Shareable across multiple pods (though configured as RWO in this lab).
     - Used to store the `insertdata.sql` file, copied from the `file-sharing` deployment and accessed by the `dbserver` deployment.
     - Slower than local storage but necessary for shared access.

#### Services
Services in the lab provide network connectivity between applications:

1. **mysql-service**:
   - **Purpose**: Exposes the `dbserver` deployment to allow the `file-sharing` web application to connect to the MySQL database.
   - **Port**: 3306 (MySQL default port).
   - **Type**: ClusterIP (internal to the cluster).
   - **Selector**: Matches pods with the label `app: dbserver`.
   - **Usage**: The `file-sharing` application uses the service’s ClusterIP (`172.30.240.100:3306`) to connect to the database.

2. **file-sharing**:
   - **Purpose**: Exposes the `file-sharing` deployment to allow internal and external access to the PHP web application.
   - **Port**: 8080 (web server port).
   - **Type**: ClusterIP (internal, exposed externally via a Route).
   - **Selector**: Matches pods with the label `app: file-sharing`.
   - **Usage**: The service load-balances traffic across the two `file-sharing` pods and is exposed externally via the `file-sharing` route.

#### Route
- **file-sharing Route**:
  - **Purpose**: Provides external access to the `file-sharing` service at `http://file-sharing-storage-review.apps.ocp4.example.com`.
  - **Usage**: Allows users to access the web application in a browser to verify connectivity with the database and view data from the `world_x` database.

---

### YAML Files for All Resources

Below are the complete YAML files for all resources created in the lab, consolidating the configurations described above.

1. **Secret: world-cred**
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: world-cred
     namespace: storage-review
   type: Opaque
   data:
     user: cmVkaGF0
     password: cmVkaGF0MTIz
     database: d29ybGRfeA==
   ```

2. **ConfigMap: dbfiles**
   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: dbfiles
     namespace: storage-review
   data:
     insertdata.sql: |
       -- MySQL dump 10.13  Distrib 8.0.19, for osx10.14 (x86_64)
       --
       -- Host: 127.0.0.1    Database: world_x
       -- ------------------------------------------------------
       -- Server version 8.0.19-debug
       ... (content of insertdata.sql)
   ```

3. **Deployment: dbserver (with volumes and environment variables)**
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: dbserver
     namespace: storage-review
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: dbserver
     template:
       metadata:
         labels:
           app: dbserver
       spec:
         containers:
         - name: dbserver
           image: registry.ocp4.example.com:8443/redhattraining/mysql-app:v1
           env:
           - name: MYSQL_USER
             valueFrom:
               secretKeyRef:
                 name: world-cred
                 key: user
           - name: MYSQL_PASSWORD
             valueFrom:
               secretKeyRef:
                 name: world-cred
                 key: password
           - name: MYSQL_DATABASE
             valueFrom:
               secretKeyRef:
                 name: world-cred
                 key: database
           volumeMounts:
           - name: dbserver-lvm
             mountPath: /var/lib/mysql
           - name: shared-volume
             mountPath: /home/sharedfiles
         volumes:
         - name: dbserver-lvm
           persistentVolumeClaim:
             claimName: dbserver-lvm-pvc
         - name: shared-volume
           persistentVolumeClaim:
             claimName: shared-pvc
   ```

4. **Deployment: file-sharing (with volumes and scaling)**
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: file-sharing
     namespace: storage-review
   spec:
     replicas: 2
     selector:
       matchLabels:
         app: file-sharing
     template:
       metadata:
         labels:
           app: file-sharing
       spec:
         containers:
         - name: file-sharing
           image: registry.ocp4.example.com:8443/redhattraining/php-webapp-mysql:v1
           volumeMounts:
           - name: shared-volume
             mountPath: /home/sharedfiles
         volumes:
         - name: shared-volume
           persistentVolumeClaim:
             claimName: shared-pvc
   ```

5. **PersistentVolumeClaim: dbserver-lvm-pvc**
   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: dbserver-lvm-pvc
     namespace: storage-review
   spec:
     accessModes:
     - ReadWriteOnce
     resources:
       requests:
         storage: 1Gi
     storageClassName: lvms-vg1
   ```

6. **PersistentVolumeClaim: shared-pvc**
   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: shared-pvc
     namespace: storage-review
   spec:
     accessModes:
     - ReadWriteOnce
     resources:
       requests:
         storage: 1Gi
     storageClassName: nfs-storage
   ```

7. **Service: mysql-service**
   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: mysql-service
     namespace: storage-review
   spec:
     selector:
       app: dbserver
     ports:
     - port: 3306
       targetPort: 3306
       protocol: TCP
   ```

8. **Service: file-sharing**
   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: file-sharing
     namespace: storage-review
   spec:
     selector:
       app: file-sharing
     ports:
     - port: 8080
       targetPort: 8080
       protocol: TCP
   ```

9. **Route: file-sharing**
   ```yaml
   apiVersion: route.openshift.io/v1
   kind: Route
   metadata:
     name: file-sharing
     namespace: storage-review
   spec:
     host: file-sharing-storage-review.apps.ocp4.example.com
     to:
       kind: Service
       name: file-sharing
     port:
       targetPort: 8080
   ```

---

### Summary of Outcomes
The lab achieves the following:
- **Database Server**: Deployed as `dbserver` with local storage (`dbserver-lvm-pvc`) and shared NFS storage (`shared-pvc`).
- **Web Application**: Deployed as `file-sharing` with two replicas, using shared NFS storage and a ConfigMap for configuration.
- **Secret**: `world-cred` provides secure database credentials.
- **ConfigMap**: `dbfiles` supplies the `insertdata.sql` file.
- **Volumes**: Added and removed as required (`dbserver-lvm`, `config-map-pvc`, `shared-volume`).
- **Services**: `mysql-service` and `file-sharing` enable internal communication.
- **Route**: Exposes the web application externally.
- **Scaling**: The `file-sharing` deployment is scaled to two replicas.
- **Verification**: Connectivity between the web application and database is confirmed via a browser.

This setup demonstrates the use of Kubernetes/OpenShift storage and networking primitives to build a scalable, storage-aware application environment.
