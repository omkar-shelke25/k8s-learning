To convert the provided `oc` commands into equivalent YAML manifests for OpenShift/Kubernetes, we need to represent the resources created by each command: deployments, services, and a route. Below are the YAML files that replicate the functionality of your commands.

The commands create:
1. A MySQL deployment (`mysql-app`) with environment variables.
2. A MySQL service (`mysql-service`).
3. A PHP deployment (`php-app`).
4. A PHP service (`php-svc`).
5. A route (`phpapp`) for the PHP service.

Since the `oc exec` command is a one-time action to import data and not a persistent resource, it doesn’t translate to a YAML file. Instead, you’d run it separately after applying the manifests.

---

### 1. MySQL Deployment (`mysql-app-deployment.yaml`)
This YAML defines the `mysql-app` deployment with the specified image and environment variables.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-app
  namespace: <your-namespace> # Replace with your namespace, or omit for default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql-app
  template:
    metadata:
      labels:
        app: mysql-app
    spec:
      containers:
      - name: mysql-app
        image: registry.ocp4.example.com:8443/redhattraining/mysql-app:v1
        env:
        - name: MYSQL_USER
          value: "redhat"
        - name: MYSQL_PASSWORD
          value: "redhat123"
        - name: MYSQL_DATABASE
          value: "world_x"
        ports:
        - containerPort: 3306
```

**Notes**:
- The `replicas: 1` is implied by the default behavior of `oc create deployment`.
- The `app: mysql-app` label ensures the service can select the pods.
- Environment variables are set as per the `oc set env` command.

---

### 2. MySQL Service (`mysql-service.yaml`)
This YAML defines the `mysql-service` to expose the MySQL deployment.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-service
  namespace: <your-namespace> # Replace with your namespace, or omit for default
spec:
  selector:
    app: mysql-app
  ports:
  - port: 3306
    targetPort: 3306
    protocol: TCP
```

**Notes**:
- The `selector` matches the `app: mysql-app` label from the deployment.
- `port` and `targetPort` are set to `3306` as per the `oc expose` command.

---

### 3. PHP Deployment (`php-app-deployment.yaml`)
This YAML defines the `php-app` deployment with the specified image.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-app
  namespace: <your-namespace> # Replace with your namespace, or omit for default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: php-app
  template:
    metadata:
      labels:
        app: php-app
    spec:
      containers:
      - name: php-app
        image: registry.ocp4.example.com:8443/redhattraining/php-webapp:v1
        ports:
        - containerPort: 8080
```

**Notes**:
- Similar to the MySQL deployment, it uses a single replica by default.
- The `app: php-app` label is used for service selection.
- Port `8080` is exposed as per the application’s configuration.

---

### 4. PHP Service (`php-svc.yaml`)
This YAML defines the `php-svc` service to expose the PHP deployment.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: php-svc
  namespace: <your-namespace> # Replace with your namespace, or omit for default
spec:
  selector:
    app: php-app
  ports:
  - port: 8080
    targetPort: 8080
    protocol: TCP
```

**Notes**:
- The `selector` matches the `app: php-app` label.
- `port` and `targetPort` are set to `8080` as per the `oc expose` command.

---

### 5. PHP Route (`phpapp-route.yaml`)
This YAML defines the `phpapp` route to expose the `php-svc` service externally.

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: phpapp
  namespace: <your-namespace> # Replace with your namespace, or omit for default
spec:
  to:
    kind: Service
    name: php-svc
  port:
    targetPort: 8080
  wildcardPolicy: None
```

**Notes**:
- The route targets the `php-svc` service on port `8080`.
- `wildcardPolicy: None` is the default, matching the `oc expose` behavior.
- The route will generate a URL like `http://phpapp-<namespace>.apps.ocp4.example.com`.

---

### Applying the YAML Files
1. Save each YAML file with the appropriate name (e.g., `mysql-app-deployment.yaml`).
2. Replace `<your-namespace>` with your actual OpenShift namespace, or remove the `namespace` field if using the default or current namespace.
3. Apply the files using:
   ```bash
   oc apply -f mysql-app-deployment.yaml
   oc apply -f mysql-service.yaml
   oc apply -f php-app-deployment.yaml
   oc apply -f php-svc.yaml
   oc apply -f phpapp-route.yaml
   ```

4. **Data Import**:
   - The `oc exec` command for importing the SQL file isn’t part of a YAML manifest since it’s a one-time action. After the MySQL deployment is running, execute:
     ```bash
     oc exec -it <mysql-pod-name> -- /bin/bash -c "mysql -uredhat -predhat123 </tmp/world_x.sql"
     ```
     Replace `<mysql-pod-name>` with the actual pod name (find it using `oc get pods`).

---

### Verifying the Deployment
- Check deployments:
  ```bash
  oc get deployments
  ```
- Check services:
  ```bash
  oc get svc
  ```
- Check route:
  ```bash
  oc get route phpapp
  ```
- Access the PHP application using the route URL (e.g., `http://phpapp-<namespace>.apps.ocp4.example.com`) from your mobile or browser.

---

### Notes
- **Namespace**: Ensure all resources are in the same namespace if you specify one. If you omit `namespace`, they’ll be created in the current namespace.
- **Image Access**: The images (`registry.ocp4.example.com:8443/redhattraining/mysql-app:v1` and `php-webapp:v1`) must be accessible by the cluster. If the registry requires authentication, ensure the OpenShift image pull secrets are configured.
- **SQL File**: The `/tmp/world_x.sql` file must exist in the MySQL pod’s filesystem. If it’s not included in the image, you may need to copy it to the pod using `oc cp` before running the `oc exec` command.
- **Route URL**: The route assumes a default HTTP configuration. If your cluster enforces HTTPS, you may need to add `tls` configuration to the route YAML.

This YAML-based setup achieves the same result as your `oc` commands and allows for declarative management of the resources. Let me know if you need help applying these or tweaking the configuration!
