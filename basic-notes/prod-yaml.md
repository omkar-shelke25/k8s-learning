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
