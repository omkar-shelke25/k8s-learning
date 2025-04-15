Below is a single Kubernetes YAML file that combines all the resources to replicate the provided OpenShift (`oc`) commands in a Kubernetes environment. The file includes:
1. A MySQL deployment (`mysql-app`) with environment variables.
2. A MySQL service (`mysql-service`).
3. A PHP deployment (`php-app`).
4. A PHP service (`php-svc`).
5. An Ingress (`phpapp`) to expose the PHP application externally.

I’ll explain each resource in the YAML file, its purpose, how it maps to the original `oc` commands, and how the components communicate. The `oc exec` command for importing the SQL file is a one-time action and not included in the YAML, but I’ll provide instructions for it separately.

---

### Kubernetes YAML File (`mysql-php-app.yaml`)

```yaml
```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-app
  namespace: default # Replace with your namespace if needed
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
---
apiVersion: v1
kind: Service
metadata:
  name: mysql-service
  namespace: default # Replace with your namespace if needed
spec:
  selector:
    app: mysql-app
  ports:
  - port: 3306
    targetPort: 3306
    protocol: TCP
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-app
  namespace: default # Replace with your namespace if needed
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
---
apiVersion: v1
kind: Service
metadata:
  name: php-svc
  namespace: default # Replace with your namespace if needed
spec:
  selector:
    app: php-app
  ports:
  - port: 8080
    targetPort: 8080
    protocol: TCP
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: phpapp
  namespace: default # Replace with your namespace if needed
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: / # Optional, for NGINX Ingress
spec:
  rules:
  - host: phpapp.example.com # Replace with your domain
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: php-svc
            port:
              number: 8080
```
```

---

### Explanation of Each Resource

#### 1. MySQL Deployment (`mysql-app`)
**YAML Section**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-app
  namespace: default
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

**Purpose**:
- Deploys a MySQL database pod using the specified image.
- Configures the database with environment variables for user, password, and database name.

**Mapping to `oc` Commands**:
- `oc create deployment mysql-app --image registry.ocp4.example.com:8443/redhattraining/mysql-app:v1`: Creates the deployment with the image.
- `oc set env deployment/mysql-app MYSQL_USER=redhat MYSQL_PASSWORD=redhat123 MYSQL_DATABASE=world_x`: Sets the environment variables.

**Details**:
- `replicas: 1`: Ensures one pod runs (default for `oc create deployment`).
- `selector` and `labels`: The `app: mysql-app` label links the deployment to its pods and allows the service to select them.
- `image`: Pulls the MySQL image from the specified registry.
- `env`: Defines the MySQL credentials and database name.
- `containerPort: 3306`: Exposes the default MySQL port.

#### 2. MySQL Service (`mysql-service`)
**YAML Section**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-service
  namespace: default
spec:
  selector:
    app: mysql-app
  ports:
  - port: 3306
    targetPort: 3306
    protocol: TCP
  type: ClusterIP
```

**Purpose**:
- Creates a stable internal endpoint for accessing the MySQL pods within the cluster.

**Mapping to `oc` Command**:
- `oc expose deployment mysql-app --name mysql-service --port 3306 --target-port 3306`: Exposes the deployment as a service.

**Details**:
- `selector: app: mysql-app`: Targets pods with the `app: mysql-app` label.
- `port: 3306` and `targetPort: 3306`: Routes traffic to the MySQL pods’ port `3306`.
- `type: ClusterIP`: Makes the service accessible only within the cluster (default for internal services).
- The service DNS name is `mysql-service.default.svc.cluster.local` (or `mysql-service` within the same namespace).

#### 3. PHP Deployment (`php-app`)
**YAML Section**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-app
  namespace: default
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

**Purpose**:
- Deploys a PHP web application pod using the specified image.

**Mapping to `oc` Command**:
- `oc create deployment php-app --image registry.ocp4.example.com:8443/redhattraining/php-webapp:v1`: Creates the deployment.

**Details**:
- `replicas: 1`: Runs one pod.
- `selector` and `labels`: The `app: php-app` label links the deployment to its pods.
- `image`: Pulls the PHP image from the registry.
- `containerPort: 8080`: Exposes the port where the PHP app listens.

#### 4. PHP Service (`php-svc`)
**YAML Section**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: php-svc
  namespace: default
spec:
  selector:
    app: php-app
  ports:
  - port: 8080
    targetPort: 8080
    protocol: TCP
  type: ClusterIP
```

**Purpose**:
- Provides an internal endpoint for accessing the PHP pods, used by the Ingress for external traffic.

**Mapping to `oc` Command**:
- `oc expose deployment php-app --name php-svc --port 8080 --target-port 8080`: Exposes the deployment as a service.

**Details**:
- `selector: app: php-app`: Targets PHP pods.
- `port: 8080` and `targetPort: 8080`: Routes traffic to the PHP pods’ port `8080`.
- `type: ClusterIP`: Internal service, as the Ingress handles external access.
- DNS name: `php-svc.default.svc.cluster.local` (or `php-svc` in the same namespace).

#### 5. Ingress (`phpapp`)
**YAML Section**:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: phpapp
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: / # Optional, for NGINX Ingress
spec:
  rules:
  - host: phpapp.example.com # Replace with your domain
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: php-svc
            port:
              number: 8080
```

**Purpose**:
- Exposes the PHP application externally via a domain, replacing OpenShift’s `Route`.

**Mapping to `oc` Command**:
- `oc expose service/php-svc --name phpapp`: Creates a route, which Ingress replicates in Kubernetes.

**Details**:
- `host: phpapp.example.com`: Specifies the domain for accessing the app. Replace with your domain or a testable placeholder.
- `path: /`: Routes all requests to the `php-svc` service.
- `backend`: Forwards traffic to `php-svc` on port `8080`.
- `annotations`: The `rewrite-target` is specific to NGINX Ingress; adjust or remove based on your Ingress controller (e.g., Traefik, HAProxy).
- Requires an Ingress controller (e.g., NGINX) to process requests.

---

### Communication Between Components
1. **PHP to MySQL**:
   - The PHP app connects to MySQL using the service DNS: `mysql-service.default.svc.cluster.local:3306` (or `mysql-service:3306` in the same namespace).
   - Uses credentials `redhat`/`redhat123` to access the `world_x` database.
   - Example PHP connection:
     ```php
     $conn = mysqli_connect("mysql-service", "redhat", "redhat123", "world_x", 3306);
     ```

2. **Mobile/Client to PHP**:
   - External clients access the PHP app via the Ingress domain (e.g., `http://phpapp.example.com`).
   - The Ingress controller routes traffic to `php-svc` on port `8080`, which load-balances to PHP pods.
   - If TLS is configured, use `https://phpapp.example.com`.

3. **Internal Communication**:
   - Services (`mysql-service`, `php-svc`) use `ClusterIP` for internal load balancing.
   - Pods communicate via service DNS names within the cluster.

---

### Instructions for Deployment

1. **Save the YAML**:
   - Save the YAML as `mysql-php-app.yaml`.

2. **Customize the YAML**:
   - **Namespace**: Replace `default` with your namespace if needed. Ensure all resources use the same namespace.
   - **Ingress Host**: Replace `phpapp.example.com` with a domain you control or a placeholder. Ensure it resolves to the Ingress controller’s IP (see below).
   - **Image Registry**: If `registry.ocp4.example.com:8443` is private, create an image pull secret:
     ```bash
     kubectl create secret docker-registry registry-secret \
       --docker-server=registry.ocp4.example.com:8443 \
       --docker-username=<username> \
       --docker-password=<password> \
       --docker-email=<email> \
       -n default
     ```
     Add to deployments:
     ```yaml
     spec:
       imagePullSecrets:
       - name: registry-secret
     ```

3. **Ensure Ingress Controller**:
   - You need an Ingress controller (e.g., NGINX) installed. Install NGINX Ingress if not present:
     ```bash
     kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
     ```
   - Verify it’s running:
     ```bash
     kubectl get pods -n ingress-nginx
     ```

4. **Apply the YAML**:
   ```bash
   kubectl apply -f mysql-php-app.yaml
   ```

5. **Import SQL Data**:
   - Run the equivalent of the `oc exec` command:
     ```bash
     kubectl exec -it $(kubectl get pods -l app=mysql-app -o jsonpath="{.items[0].metadata.name}") \
       -- /bin/bash -c "mysql -uredhat -predhat123 </tmp/world_x.sql"
     ```
   - If `/tmp/world_x.sql` isn’t in the MySQL pod, copy it:
     ```bash
     kubectl cp world_x.sql $(kubectl get pods -l app=mysql-app -o jsonpath="{.items[0].metadata.name}"):/tmp/world_x.sql
     ```

6. **Set Up DNS for Ingress**:
   - Get the Ingress controller’s external IP:
     ```bash
     kubectl get svc -n ingress-nginx
     ```
     Look for the `EXTERNAL-IP` of `ingress-nginx-controller`.
   - Point `phpapp.example.com` to this IP via:
     - DNS provider (if you own the domain).
     - Local `/etc/hosts` for testing (e.g., `<external-ip> phpapp.example.com`).
   - Test access: `curl http://phpapp.example.com --resolve phpapp.example.com:80:<external-ip>`.

7. **Access from Mobile**:
   - Open `http://phpapp.example.com` in your mobile browser.
   - If HTTPS is needed, add TLS to the Ingress:
     ```yaml
     spec:
       tls:
       - hosts:
         - phpapp.example.com
         secretName: phpapp-tls
     ```
     Create a TLS secret:
     ```bash
     kubectl create secret tls phpapp-tls --cert=path/to/cert --key=path/to/key -n default
     ```

8. **Verify Resources**:
   - Deployments: `kubectl get deployments`
   - Services: `kubectl get svc`
   - Ingress: `kubectl get ingress`
   - Pods: `kubectl get pods`

---

### Troubleshooting
- **Ingress Not Responding**:
  - Check Ingress controller pods: `kubectl get pods -n ingress-nginx`.
  - View Ingress events: `kubectl describe ingress phpapp`.
  - Verify DNS resolution or test with `curl`.
- **Pods Failing**:
  - Check logs: `kubectl logs <pod-name>`.
  - Inspect events: `kubectl describe pod <pod-name>`.
  - Ensure images are accessible (check pull secrets if private registry).
- **SQL Import Issues**:
  - Confirm `/tmp/world_x.sql` exists in the pod.
  - Check MySQL logs: `kubectl logs <mysql-pod-name>`.
- **No External Access**:
  - Ensure the Ingress controller has an external IP.
  - Verify firewall rules allow traffic to the Ingress IP.

---

### Why Ingress?
- Ingress is the Kubernetes equivalent to OpenShift’s `Route`, providing domain-based routing and load balancing.
- It requires an Ingress controller but is more flexible than `LoadBalancer` for multiple services under one IP.
- If your cluster doesn’t support Ingress, you can modify `php-svc` to `type: LoadBalancer`:
  ```yaml
  spec:
    type: LoadBalancer
  ```
  Access via the external IP: `kubectl get svc php-svc`.

This YAML and workflow fully replicate the OpenShift setup in Kubernetes, with detailed explanations for each component. If you need help with Ingress setup, TLS, DNS, or an alternative approach, let me know!
