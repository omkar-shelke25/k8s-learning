I understand you’re asking for a Kubernetes (K8s) setup for the previously defined services (server and client) in a cloud environment, focusing on replacing the localhost configuration with a cloud-native approach using Kubernetes. The earlier setup used Docker Compose with `localhost` (`127.0.0.1`) for a server on port `49152` and a client on port `49153`, with `VITE_BACKEND_URL=http://localhost:49152` hardcoded for local development. For the cloud, you requested a configuration that handles IP addresses or domains suitable for a cloud environment, avoiding environment variables and maintaining security (non-root users, restrictive permissions, non-guessable ports, and maintainer "Omkar Shelke <omkar.shelke@proton.me>"). Since you’ve now specified a cloud setup with Kubernetes, I’ll provide a **Kubernetes configuration** to deploy these services on a managed Kubernetes cluster (e.g., AWS EKS, Google GKE, or Azure AKS), replacing `localhost` with a cloud-accessible endpoint (e.g., a LoadBalancer service with a public IP or domain).

### Key Requirements:
- **Cloud Environment with Kubernetes**:
  - Deploy the `server` (port `49152`) and `client` (port `49153`) as Kubernetes **Deployments**.
  - Expose the services using Kubernetes **Services** (type `LoadBalancer`) to assign public cloud IPs or domains, replacing `localhost`.
  - Update `VITE_BACKEND_URL` to use the server’s cloud-assigned endpoint (e.g., a public IP or domain like `https://server.yourdomain.com`).
- **No Environment Variables**:
  - Hardcode ports (`49152` for server, `49153` for client) and `VITE_BACKEND_URL` in the Dockerfiles or Kubernetes manifests.
- **Security**:
  - Use `node:22-alpine`, non-root users, restrictive permissions, and health checks.
  - Maintain non-guessable ports (`49152`, `49153`).
- **IP Address Handling**:
  - **Localhost**: Not used in cloud; replaced by Kubernetes Service IPs (internal) or public LoadBalancer IPs/domains (external).
  - **Cloud**: Internal communication uses Kubernetes Service names (e.g., `code-sync-server:49152`). External access uses a cloud-assigned public IP or domain.
- **Single Artifact**:
  - Provide a single YAML file containing all Kubernetes manifests (Deployments, Services) with comments explaining cloud IP handling.
- **Assumptions**:
  - The `server` and `client` are Node.js applications built into a `dist` folder, served with `npx serve`.
  - Images are pushed to a container registry (e.g., Docker Hub, AWS ECR).
  - A managed Kubernetes cluster (e.g., EKS, GKE, AKS) is available.
  - The `public` folder is included but can be removed if not needed (noted in comments).

### Strategy:
- **Docker Images**:
  - Reuse the previous Dockerfiles for `server` and `client`, with modifications:
    - **Server**: Hardcode port `49152`.
    - **Client**: Hardcode `VITE_BACKEND_URL` to the server’s cloud endpoint (e.g., `https://server.yourdomain.com` or a placeholder for the LoadBalancer IP).
  - Build and push images to a registry.
- **Kubernetes Manifests**:
  - **Deployments**: Define `code-sync-server` and `code-sync-client` with one replica each, using the Docker images.
  - **Services**: Use `LoadBalancer` type to expose both services externally:
    - `code-sync-server`: Maps to port `49152`, assigns a public IP (e.g., `<server-public-ip>:49152`).
    - `code-sync-client`: Maps to port `49153`, assigns a public IP (e.g., `<client-public-ip>:49153`).
  - **Health Checks**: Use Kubernetes liveness/readiness probes instead of Docker health checks.
- **Cloud IP Handling**:
  - Internal: Containers communicate via Service names (e.g., `code-sync-server:49152`).
  - External: The frontend (browser) uses the server’s LoadBalancer IP/domain (e.g., `https://server.yourdomain.com` or `<server-public-ip>:49152`).
  - Update `VITE_BACKEND_URL` post-deployment if using a dynamic IP (manual step, as no environment variables are allowed).
- **Security**:
  - Run pods as non-root with a security context.
  - Use read-only root filesystem where possible.
  - Apply resource limits to prevent overconsumption.

### Project Structure
```
project-root/
├── server/
│   ├── Dockerfile
│   ├── package.json
│   ├── package-lock.json (optional)
│   ├── src/ (or other source files)
│   └── public/ (if needed)
├── client/
│   ├── Dockerfile
│   ├── package.json
│   ├── package-lock.json (optional)
│   ├── src/ (or other source files)
│   └── public/ (if needed)
└── k8s/
    └── manifests.yaml
```

### Dockerfiles
#### Server Dockerfile (`./server/Dockerfile`)
```dockerfile
# Stage 1: Build the project
FROM node:22-alpine AS builder

WORKDIR /build

# Copy package files first for better layer caching
COPY package.json package-lock.json* ./

# Install build dependencies securely and efficiently
RUN npm ci --prefer-offline --no-audit --progress=false && \
    rm -rf /root/.npm /root/.node-gyp

# Copy the rest of the source code
COPY . .

# Build the application
RUN npm run build

# Prune dev dependencies for a leaner image
RUN npm prune --omit=dev

# Stage 2: Serve the application
FROM node:22-alpine AS runner

# Add labels for better maintainability
LABEL maintainer="Omkar Shelke <omkar.shelke@proton.me>"
LABEL version="1.0"
LABEL description="Secure Node.js server for Kubernetes cloud deployment"

WORKDIR /app

# Create non-root user and group with minimal privileges
RUN addgroup -g 1001 -S appgroup && \
    adduser -S -u 1001 -G appgroup -H -D appuser && \
    mkdir -p /app && \
    chown -R appuser:appgroup /app

# Copy necessary artifacts with correct permissions
COPY --from=builder --chown=appuser:appgroup /build/dist ./dist/
COPY --from=builder --chown=appuser:appgroup /build/public ./public/
# Note: Remove the above line if `public` folder is not needed (e.g., Vite merges into `dist`).
COPY --from=builder --chown=appuser:appgroup /build/node_modules ./node_modules/
COPY --from=builder --chown=appuser:appgroup /build/package.json ./package.json
COPY --from=builder --chown=appuser:appgroup /build/package-lock.json* ./package-lock.json

# Switch to non-root user
USER appuser

# Restrict file system access
RUN chmod -R 500 ./dist ./public ./node_modules && \
    chmod 400 ./package.json ./package-lock.json*
# Note: If `public` folder is not copied, remove `./public` from the chmod command.

# Expose non-standard port
EXPOSE 49152
# Cloud: The server listens on port 49152, accessible internally via `code-sync-server:49152`
# (Kubernetes Service name) or externally via a cloud-assigned public IP
# (e.g., `<server-public-ip>:49152`) or domain (e.g., `server.yourdomain.com`).
# IP Address: Pods get cluster-internal IPs (e.g., 10.0.0.x), but external access uses
# the LoadBalancer’s public IP.

# Start the server on hardcoded port
CMD ["npx", "serve", "-s", "dist", "-l", "49152", "--no-clipboard", "--no-port-switching"]
# Hardcodes port 49152 for cloud deployment, accessible via Kubernetes Service.
```

#### Client Dockerfile (`./client/Dockerfile`)
```dockerfile
# Stage 1: Build the project
FROM node:22-alpine AS builder

WORKDIR /build

# Copy package files first for better layer caching
COPY package.json package-lock.json* ./

# Install build dependencies securely and efficiently
RUN npm ci --prefer-offline --no-audit --progress=false && \
    rm -rf /root/.npm /root/.node-gyp

# Copy the rest of the source code
COPY . .

# Create .env file for Vite build with cloud URL
RUN echo "VITE_BACKEND_URL=https://server.yourdomain.com" > .env
# Cloud: Hardcodes VITE_BACKEND_URL for the server’s cloud endpoint.
# Replace `server.yourdomain.com` with the actual domain or LoadBalancer IP
# (e.g., `http://<server-public-ip>:49152`) after deployment.
# IP Address: The frontend (browser) uses the server’s public IP or domain, resolved
# externally. Internal pod IPs or Service IPs (e.g., `code-sync-server:49152`) are
# not used, as API requests originate from the browser outside the cluster.
# Note: If the LoadBalancer IP is unknown at build time, rebuild the image with the
# assigned IP or use a domain with DNS configured.

# Build the application
RUN npm run build

# Prune dev dependencies for a leaner image
RUN npm prune --omit=dev

# Stage 2: Serve the application
FROM node:22-alpine AS runner

# Add labels for better maintainability
LABEL maintainer="Omkar Shelke <omkar.shelke@proton.me>"
LABEL version="1.0"
LABEL description="Secure Node.js client for Kubernetes cloud deployment"

WORKDIR /app

# Create non-root user and group with minimal privileges
RUN addgroup -g 1001 -S appgroup && \
    adduser -S -u 1001 -G appgroup -H -D appuser && \
    mkdir -p /app && \
    chown -R appuser:appgroup /app

# Copy necessary artifacts with correct permissions
COPY --from=builder --chown=appuser:appgroup /build/dist ./dist/
COPY --from=builder --chown=appuser:appgroup /build/public ./public/
# Note: Remove the above line if `public` folder is not needed.
COPY --from=builder --chown=appuser:appgroup /build/node_modules ./node_modules/
COPY --from=builder --chown=appuser:appgroup /build/package.json ./package.json
COPY --from=builder --chown=appuser:appgroup /build/package-lock.json* ./package-lock.json

# Switch to non-root user
USER appuser

# Restrict file system access
RUN chmod -R 500 ./dist ./public ./node_modules && \
    chmod 400 ./package.json ./package-lock.json*
# Note: If `public` folder is not copied, remove `./public` from the chmod command.

# Expose non-standard port
EXPOSE 49153
# Cloud: The client listens on port 49153, accessible internally via
# `code-sync-client:49153` or externally via a cloud-assigned public IP
# (e.g., `<client-public-ip>:49153`) or domain (e.g., `client.yourdomain.com`).
# IP Address: External access uses the LoadBalancer’s public IP.

# Start the server on hardcoded port
CMD ["npx", "serve", "-s", "dist", "-l", "49153", "--no-clipboard", "--no-port-switching"]
# Hardcodes port 49153 for cloud deployment.
```

### Kubernetes Manifests
```yaml
```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: code-sync-server
  namespace: default
  labels:
    app: code-sync-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: code-sync-server
  template:
    metadata:
      labels:
        app: code-sync-server
    spec:
      securityContext:
        runAsUser: 1001
        runAsGroup: 1001
        fsGroup: 1001
        # Runs the pod as non-root user `appuser` (UID 1001, GID 1001).
        # Cloud: Ensures containers run securely in the Kubernetes cluster.
      containers:
        - name: server
          image: <your-registry>/code-sync-server:latest
          # Cloud: Replace `<your-registry>` with your container registry
          # (e.g., `docker.io/yourusername` or `123456789012.dkr.ecr.us-east-1.amazonaws.com`).
          # The image is built from `./server/Dockerfile` and pushed to the registry.
          ports:
            - containerPort: 49152
              # Exposes port 49152, matching the server’s hardcoded port.
          resources:
            limits:
              cpu: "500m"
              memory: "512Mi"
            requests:
              cpu: "200m"
              memory: "256Mi"
            # Cloud: Limits resource usage to prevent overconsumption.
          livenessProbe:
            httpGet:
              path: /
              port: 49152
            initialDelaySeconds: 15
            periodSeconds: 30
            timeoutSeconds: 3
            # Cloud: Verifies the server is running by checking `http://localhost:49152`
            # inside the container (pod-internal).
          readinessProbe:
            httpGet:
              path: /
              port: 49152
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 3
            # Cloud: Ensures the server is ready to receive traffic.
          securityContext:
            readOnlyRootFilesystem: true
            allowPrivilegeEscalation: false
            # Enhances security by restricting filesystem writes and privilege escalation.
          volumeMounts:
            - name: tmp
              mountPath: /tmp
              # Provides a writable /tmp directory, as the root filesystem is read-only.
      volumes:
        - name: tmp
          emptyDir: {}
          # Cloud: Provides a temporary writable volume for /tmp.

---
apiVersion: v1
kind: Service
metadata:
  name: code-sync-server
  namespace: default
  labels:
    app: code-sync-server
spec:
  selector:
    app: code-sync-server
  ports:
    - protocol: TCP
      port: 49152
      targetPort: 49152
      # Maps Service port 49152 to container port 49152.
  type: LoadBalancer
  # Cloud: Creates a cloud provider load balancer (e.g., AWS ELB, GCP Load Balancer)
  # assigning a public IP (e.g., `<server-public-ip>:49152`) or DNS name
  # (e.g., `a1234567890abcdef.elb.us-east-1.amazonaws.com:49152`).
  # IP Address: Internally, pods use `code-sync-server:49152` (cluster IP, e.g., 10.0.0.1).
  # Externally, the frontend (browser) uses the public IP or a domain
  # (e.g., `server.yourdomain.com` if DNS is configured).
  # Localhost: Not used in cloud; `localhost:49152` is replaced by the LoadBalancer IP.

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: code-sync-client
  namespace: default
  labels:
    app: code-sync-client
spec:
  replicas: 1
  selector:
    matchLabels:
      app: code-sync-client
  template:
    metadata:
      labels:
        app: code-sync-client
    spec:
      securityContext:
        runAsUser: 1001
        runAsGroup: 1001
        fsGroup: 1001
        # Runs the pod as non-root user `appuser`.
      containers:
        - name: client
          image: <your-registry>/code-sync-client:latest
          # Cloud: Replace `<your-registry>` with your container registry.
          # The image is built from `./client/Dockerfile` with
          # `VITE_BACKEND_URL=https://server.yourdomain.com`.
          ports:
            - containerPort: 49153
              # Exposes port 49153, matching the client’s hardcoded port.
          resources:
            limits:
              cpu: "500m"
              memory: "512Mi"
            requests:
              cpu: "200m"
              memory: "256Mi"
          livenessProbe:
            httpGet:
              path: /
              port: 49153
            initialDelaySeconds: 15
            periodSeconds: 30
            timeoutSeconds: 3
          readinessProbe:
            httpGet:
              path: /
              port: 49153
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 3
          securityContext:
            readOnlyRootFilesystem: true
            allowPrivilegeEscalation: false
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}

---
apiVersion: v1
kind: Service
metadata:
  name: code-sync-client
  namespace: default
  labels:
    app: code-sync-client
spec:
  selector:
    app: code-sync-client
  ports:
    - protocol: TCP
      port: 49153
      targetPort: 49153
      # Maps Service port 49153 to container port 49153.
  type: LoadBalancer
  # Cloud: Assigns a public IP (e.g., `<client-public-ip>:49153`) or DNS name.
  # IP Address: Internally, pods use `code-sync-client:49153` (cluster IP).
  # Externally, users access the client via the public IP or a domain
  # (e.g., `client.yourdomain.com`).
```
```

### Step-by-Step Guide: How It Works
#### Step 1: Prepare the Environment
1. **Container Registry**:
   - Choose a registry (e.g., Docker Hub, AWS ECR, Google Artifact Registry).
   - Example: `docker.io/yourusername` or `123456789012.dkr.ecr.us-east-1.amazonaws.com`.
2. **Build and Push Images**:
   - **Server**:
     ```bash
     cd server
     docker build -t <your-registry>/code-sync-server:latest .
     docker push <your-registry>/code-sync-server:latest
     ```
   - **Client**:
     - Update `VITE_BACKEND_URL` in `./client/Dockerfile` to a placeholder domain (`https://server.yourdomain.com`) or leave it and update later with the server’s LoadBalancer IP.
     ```bash
     cd client
     docker build -t <your-registry>/code-sync-client:latest .
     docker push <your-registry>/code-sync-client:latest
     ```
3. **package.json**:
   - Ensure both `server` and `client` have:
     ```json
     "dependencies": {
       "serve": "^14.2.1"
     }
     ```

#### Step 2: Set Up a Kubernetes Cluster
1. **Choose a Managed Kubernetes Service**:
   - **AWS EKS**: `eksctl create cluster --name code-sync --region us-east-1 --nodegroup-name workers --nodes 2`.
   - **Google GKE**: `gcloud container clusters create code-sync --region us-central1 --num-nodes 2`.
   - **Azure AKS**: `az aks create --resource-group code-sync --name code-sync --node-count 2`.
2. **Configure kubectl**:
   - Update kubeconfig:
     - EKS: `aws eks update-kubeconfig --name code-sync --region us-east-1`.
     - GKE: `gcloud container clusters get-credentials code-sync --region us-central1`.
     - AKS: `az aks get-credentials --resource-group code-sync --name code-sync`.

#### Step 3: Deploy to Kubernetes
1. **Update Manifests**:
   - Replace `<your-registry>` in `manifests.yaml` with your registry path.
   - If using a domain, ensure `VITE_BACKEND_URL` matches (e.g., `https://server.yourdomain.com`).
   - If using a LoadBalancer IP, deploy the server first, get the IP, update the client’s Dockerfile, rebuild, and redeploy.
2. **Apply Manifests**:
   ```bash
   kubectl apply -f k8s/manifests.yaml
   ```
   **What Happens**:
   - **Server Deployment**: Runs one pod with the server image, listening on `49152`.
   - **Server Service**: Creates a LoadBalancer, assigning a public IP (e.g., `<server-public-ip>:49152`) or DNS name.
   - **Client Deployment**: Runs one pod with the client image, listening on `49153`.
   - **Client Service**: Creates a LoadBalancer, assigning a public IP (e.g., `<client-public-ip>:49153`).
   - **IP Handling**:
     - Internal: Pods use `code-sync-server:49152` or `code-sync-client:49153` (cluster IPs, e.g., `10.0.0.x`).
     - External: The browser uses `<client-public-ip>:49153` for the frontend and `<server-public-ip>:49152` (or domain) for API requests.

#### Step 4: Get LoadBalancer IPs
1. **Check Services**:
   ```bash
   kubectl get svc
   ```
   Output example:
   ```
   NAME               TYPE           CLUSTER-IP    EXTERNAL-IP        PORT(S)
   code-sync-server   LoadBalancer   10.0.0.1      <server-public-ip> 49152:31789/TCP
   code-sync-client   LoadBalancer   10.0.0.2      <client-public-ip> 49153:32456/TCP
   ```
2. **Update VITE_BACKEND_URL** (if using IP):
   - If `VITE_BACKEND_URL` was a placeholder, update `./client/Dockerfile`:
     ```dockerfile
     RUN echo "VITE_BACKEND_URL=http://<server-public-ip>:49152" > .env
     ```
   - Rebuild and push:
     ```bash
     docker build -t <your-registry>/code-sync-client:latest .
     docker push <your-registry>/code-sync-client:latest
     ```
   - Update the client deployment:
     ```bash
     kubectl rollout restart deployment/code-sync-client
     ```
3. **DNS (Optional)**:
   - Configure DNS to map `server.yourdomain.com` to `<server-public-ip>` and `client.yourdomain.com` to `<client-public-ip>`.

#### Step 5: Verify the Application
1. **Access the Client**:
   - Open a browser and navigate to `http://<client-public-ip>:49153` or `https://client.yourdomain.com`.
   - The frontend loads from the client pod.
2. **Test API Calls**:
   - The frontend sends requests to `VITE_BACKEND_URL` (e.g., `http://<server-public-ip>:49152` or `https://server.yourdomain.com`).
   - Check DevTools (Network tab) for successful requests.
3. **Check Pod Status**:
   ```bash
   kubectl get pods
   ```
   Should show `Running` for both `code-sync-server` and `code-sync-client`.
4. **Check Logs**:
   ```bash
   kubectl logs -l app=code-sync-server
   kubectl logs -l app=code-sync-client
   ```

#### Step 6: Security Verification
1. **Vulnerability Scanning**:
   ```bash
   docker run -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image <your-registry>/code-sync-server:latest
   docker run -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image <your-registry>/code-sync-client:latest
   ```
2. **Kubernetes Security**:
   - Verify non-root execution:
     ```bash
     kubectl describe pod -l app=code-sync-server
     ```
     Check `Security Context` for `runAsUser: 1001`.
   - Apply network policies (optional):
     ```yaml
     apiVersion: networking.k8s.io/v1
     kind: NetworkPolicy
     metadata:
       name: restrict-server
       namespace: default
     spec:
       podSelector:
         matchLabels:
           app: code-sync-server
       policyTypes:
       - Ingress
       ingress:
       - from:
         - podSelector:
             matchLabels:
               app: code-sync-client
         ports:
         - protocol: TCP
           port: 49152
     ```
     Apply:
     ```bash
     kubectl apply -f network-policy.yaml
     ```
3. **Cloud Firewall**:
   - Restrict access:
     ```bash
     # AWS Security Group
     aws ec2 authorize-security-group-ingress --group-id <sg-id> --protocol tcp --port 49152 --cidr 0.0.0.0/0
     aws ec2 authorize-security-group-ingress --group-id <sg-id> --protocol tcp --port 49153 --cidr 0.0.0.0/0
     # GCP Firewall
     gcloud compute firewall-rules create allow-k8s --allow tcp:49152,tcp:49153 --source-ranges 0.0.0.0/0
     # Azure NSG
     az network nsg rule create --nsg-name <nsg-name> --resource-group <rg> --name AllowK8s --protocol Tcp --destination-port-ranges 49152 49153 --source-address-prefixes '*'
     ```

#### Step 7: Cleanup
1. **Delete Resources**:
   ```bash
   kubectl delete -f k8s/manifests.yaml
   ```
2. **Delete Cluster**:
   - EKS: `eksctl delete cluster --name code-sync --region us-east-1`.
   - GKE: `gcloud container clusters delete code-sync --region us-central1`.
   - AKS: `az aks delete --resource-group code-sync --name code-sync`.
3. **Remove Images**:
   ```bash
   docker rmi <your-registry>/code-sync-server:latest <your-registry>/code-sync-client:latest
   ```

### Notes:
- **Cloud IP Handling**:
  - **Internal**: Kubernetes assigns cluster IPs (e.g., `10.0.0.x`) to Services. Pods use `code-sync-server:49152` for internal communication.
  - **External**: LoadBalancer Services provide public IPs (e.g., `<server-public-ip>:49152`). The frontend uses this IP or a domain for API requests.
  - **Localhost**: Not used in cloud; `localhost:49152` is replaced by the server’s public IP/domain.
- **VITE_BACKEND_URL**:
  - If the LoadBalancer IP is unknown at build time, use a placeholder domain and configure DNS, or rebuild the client image after getting the server’s IP.
  - Example: After deployment, if the server’s IP is `203.0.113.10`, update `./client/Dockerfile`:
    ```dockerfile
    RUN echo "VITE_BACKEND_URL=http://203.0.113.10:49152" > .env
    ```
- **Public Folder**:
  - Remove `public` references if not needed:
    ```dockerfile
    # Remove:
    COPY --from=builder --chown=appuser:appgroup /build/public ./public/
    RUN chmod -R 500 ./dist ./node_modules && \
        chmod 400 ./package.json ./package-lock.json*
    ```
- **Custom Server**:
  - For Express or other servers, update `CMD`:
    ```dockerfile
    CMD ["node", "server.js"]  # Ensure it listens on 49152 (server) or 49153 (client)
    ```
- **Ingress (Optional)**:
  - To use a single domain with paths (e.g., `server.yourdomain.com`, `client.yourdomain.com`), add an Ingress:
    ```yaml
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: code-sync-ingress
      namespace: default
      annotations:
        nginx.ingress.kubernetes.io/rewrite-target: /
    spec:
      ingressClassName: nginx
      rules:
      - host: server.yourdomain.com
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: code-sync-server
                port:
                  number: 49152
      - host: client.yourdomain.com
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: code-sync-client
                port:
                  number: 49153
    ```
    Install an Ingress controller (e.g., NGINX):
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
    ```
- **References**:
  - Kubernetes Services: https://kubernetes.io/docs/concepts/services-networking/service/[](https://kubernetes.io/docs/tutorials/kubernetes-basics/expose/expose-intro/)
  - LoadBalancer: https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer[](https://kubernetes.io/docs/concepts/services-networking/service/)

This Kubernetes setup deploys the defined services in a cloud environment, replacing `localhost` with cloud-native LoadBalancer IPs or domains. Let me know if you need help with a specific cloud provider, DNS setup, or additional Kubernetes features like autoscaling or Ingress!
