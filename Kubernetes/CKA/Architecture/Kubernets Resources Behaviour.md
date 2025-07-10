

📘 **Kubernetes Deep-Dive: Resource Placement & Behavior**

---

#### 🧠 1. Kubernetes Architecture – Core Components

- **Control Plane**: Manages cluster state, stored in `etcd`.
  - **kube-apiserver**: Handles all API requests (e.g., `kubectl get pods`).
  - **etcd**: Stores cluster data (e.g., Pod specs, Secrets).
  - **kube-scheduler**: Assigns Pods to nodes based on resources, affinity, etc.
  - **kube-controller-manager**: Runs controllers (e.g., Deployment, ReplicaSet).
  
- **Worker Nodes**: Run workloads (Pods).
  - **kubelet**: Executes Pods, communicates with API server.
  - **kube-proxy**: Manages networking (e.g., Service load balancing).
  - **Container Runtime**: Runs containers (e.g., containerd).

**Example**: A Deployment’s spec is stored in `etcd`, but its Pods run on nodes chosen by `kube-scheduler`.

---

#### ⚙️ 2. Control Plane vs. Node-Level Resources

- **Control Plane Resources** (stored in `etcd`, not node-specific):
  - **Secrets**: Store sensitive data (e.g., API keys). Mounted as volumes or env vars.
  - **ConfigMaps**: Store non-sensitive config (e.g., app settings).
  - **Deployments/StatefulSets/DaemonSets**: Define desired Pod states.
  - **PVCs/PVs**: Manage storage requests and backends.
  - **Services/Ingress**: Handle networking and scaling.

- **Node-Level Resources** (runtime, node-specific):
  - **Pods**: Run containers on a specific node.
  - **DaemonSet Pods**: One per node (e.g., `fluentd` for logging).
  - **hostPath Volumes**: Local node storage.
  - **Pod Logs**: Stored at `/var/log/containers` on the node.

**Example**: A Pod on `node-1` mounts a Secret (`db-password`) from `etcd` via `kubelet`.

---

#### 🚦 3. Node Maintenance: `cordon` vs. `drain`

- **kubectl cordon <node>**:
  - Marks node as unschedulable (`spec.unschedulable: true`).
  - New Pods won’t schedule, but existing Pods continue running.
  - **Use Case**: Prepare a node for maintenance without disrupting workloads.

- **kubectl drain <node>**:
  - Cordons the node and evicts evictable Pods.
  - Pods reschedule to other nodes if managed by a controller (e.g., Deployment).
  - **Flags**: `--ignore-daemonsets`, `--force` for non-evictable Pods.
  - **Use Case**: Safely remove a node for upgrades or decommissioning.

**Example**:
```bash
kubectl cordon node-1  # Prevent new Pods
kubectl drain node-1 --ignore-daemonsets  # Evict Pods, cordon node
```

---

#### 🔐 4. Secrets, ConfigMaps, PVCs

- **Secrets & ConfigMaps**:
  - Stored in `etcd`, fetched by `kubelet` when mounting to Pods.
  - Mounted as:
    - Volumes: `volumeMounts` (e.g., config file at `/etc/config`).
    - Env Vars: `env` or `envFrom`.
  - **Example**:
    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: app-pod
    spec:
      containers:
      - name: app
        image: nginx
        envFrom:
        - configMapRef:
            name: app-config
        volumeMounts:
        - name: secret-volume
          mountPath: "/etc/secret"
      volumes:
      - name: secret-volume
        secret:
          secretName: db-credentials
    ```

- **PVCs/PVs**:
  - **PVC**: Pod’s request for storage (e.g., 10Gi).
  - **PV**: Actual storage (e.g., NFS, EBS).
  - Node-bound if using `hostPath` or zone-specific (e.g., AWS EBS).
  - **Example**:
    ```yaml
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: data-pvc
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 5Gi
    ```

---

#### 📦 5. Resource Placement Summary

| **Resource**         | **Control Plane?** | **Runs on Node?** | **Node-Specific?** |
|-----------------------|--------------------|-------------------|--------------------|
| Pods (spec)          | ✅ Yes             | ✅ Yes            | ✅ Yes             |
| Deployments          | ✅ Yes             | ❌ No             | ❌ No              |
| Secrets              | ✅ Yes             | ❌ (mounted)      | ❌ No              |
| ConfigMaps           | ✅ Yes             | ❌ (mounted)      | ❌ No              |
| PVCs                 | ✅ Yes             | ❌ (bound)        | ❌ Usually No      |
| PVs (e.g., hostPath) | ✅ Yes             | ✅/❌ Depends      | ✅/❌ Depends       |
| Pod Logs             | ❌ No              | ✅ Yes            | ✅ Yes             |

---

#### 🧩 6. Controllers & Scheduling

- **Controllers** (in `kube-controller-manager`):
  - Ensure desired state (e.g., Deployment creates ReplicaSets, which manage Pods).
  - Examples: Deployment, StatefulSet, DaemonSet, HPA.

- **kube-scheduler**:
  - Assigns Pods to nodes based on:
    - Resource requests/limits (e.g., CPU, memory).
    - Node selectors, affinity/anti-affinity rules.
    - Taints/tolerations (e.g., `kubectl taint nodes node-1 key=value:NoSchedule`).
  - Updates Pod spec with node name; `kubelet` on that node starts the Pod.

**Example**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: disktype
                operator: In
                values:
                - ssd
```

---

#### 🔍 7. Inspecting Resources

- **Secrets/ConfigMaps**:
  - Check Pod usage: `kubectl describe pod <pod-name>`.
  - View details: `kubectl get secret <name> -o yaml`.

- **PVCs**:
  - Check binding: `kubectl describe pvc <claim-name>`.
  - See PV details: `kubectl get pv`.

**Example**:
```bash
kubectl describe pod my-app-pod  # Shows mounted Secrets/ConfigMaps
kubectl describe pvc data-pvc   # Shows bound PV
```

---

#### ✅ Key Takeaways
- **Control Plane**: Stores resource definitions (e.g., Secrets, Deployments) in `etcd`.
- **Nodes**: Run Pods, managed by `kubelet`, using resources fetched from the control plane.
- **Scheduler**: Places Pods based on constraints and resources.
- **Controllers**: Maintain desired state (e.g., 3 replicas).
- **Secrets/ConfigMaps/PVCs**: Abstract, fetched dynamically, not node-bound unless using node-specific storage.

---

### Additional Resources (Your Options)

You asked if I’d like to:
1. Export as a PDF.
2. Create a visual architecture diagram.
3. Provide a `kubectl` command cheat sheet.

Here’s how I’ll address these:

1. **PDF Export**:
   - I can’t directly generate a PDF file, but you can copy the refined notes above into a text editor (e.g., VS Code, Notion) and export them as a PDF. If you need a specific format or tool recommendation, let me know!

2. **Visual Architecture Diagram**:
   - I can’t generate images directly without confirmation (per guidelines). Would you like me to describe a Kubernetes architecture diagram in text (e.g., using ASCII or a description for tools like Mermaid)? Alternatively, I can confirm if you want me to generate a diagram using a tool like Mermaid for you to render.

   **Example Text Diagram** (simplified):
   ```
   [Control Plane]
       |-> kube-apiserver <-> etcd (Stores: Pods, Secrets, ConfigMaps)
       |-> kube-scheduler (Assigns Pods to Nodes)
       |-> kube-controller-manager (Manages Deployments, ReplicaSets)
   
   [Worker Node 1]        [Worker Node 2]
       |-> kubelet            |-> kubelet
       |-> kube-proxy         |-> kube-proxy
       |-> Pods (w/ Secrets)  |-> Pods (w/ ConfigMaps, PVCs)
   ```

   **Mermaid Code** (if you confirm you want a diagram):
   ```mermaid
   graph TD
       A[Control Plane] --> B[kube-apiserver]
       A --> C[etcd]
       A --> D[kube-scheduler]
       A --> E[kube-controller-manager]
       B --> F[Worker Node 1]
       B --> G[Worker Node 2]
       F --> H[kubelet]
       F --> I[kube-proxy]
       F --> J[Pods]
       G --> K[kubelet]
       G --> L[kube-proxy]
       G --> M[Pods]
       J --> N[Secrets/ConfigMaps]
       M --> O[PVCs]
   ```
   You can paste this into a Mermaid-compatible tool (e.g., mermaid.live) to render it.

3. **kubectl Command Cheat Sheet**:
   Below is a concise cheat sheet for common `kubectl` commands relevant to your notes:

   ```bash
   # Cluster Info
   kubectl cluster-info                 # View cluster details
   kubectl get nodes                   # List nodes
   kubectl describe node <node>        # Node details

   # Pods
   kubectl get pods                    # List Pods
   kubectl describe pod <pod>          # Pod details
   kubectl logs <pod>                  # View Pod logs

   # Resources
   kubectl get secret <name> -o yaml   # View Secret
   kubectl get configmap <name> -o yaml # View ConfigMap
   kubectl get pvc                     # List PVCs
   kubectl describe pvc <name>         # PVC details

   # Node Maintenance
   kubectl cordon <node>               # Mark node unschedulable
   kubectl drain <node> --ignore-daemonsets # Evict Pods, cordon node
   kubectl uncordon <node>             # Make node schedulable again

   # Deployments
   kubectl get deployment              # List Deployments
   kubectl rollout status deployment/<name> # Check rollout status
   kubectl scale deployment <name> --replicas=3 # Scale replicas
   ```

