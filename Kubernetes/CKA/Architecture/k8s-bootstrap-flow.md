```
[1️⃣ systemd starts kubelet service]
  │
  ├─ systemd = OS-level service manager
  └─ kubelet = node agent that manages pods locally
  🔹 No pods yet
  🔹 (No scheduler or API server running yet)
      ↓
────────────────────────────────────────────
[2️⃣ kubeadm init (Bootstrap Phase)]
  │
  ├─ Generates:
  │   - Certificates (CA, apiserver.crt, etc.)
  │   - kubeconfig files for apiserver, controller, scheduler
  │   - Static Pod YAMLs inside:
  │        📁 /etc/kubernetes/manifests/
  │        ├── kube-apiserver.yaml
  │        ├── etcd.yaml
  │        ├── kube-controller-manager.yaml
  │        └── kube-scheduler.yaml
  │
  🔸 These YAMLs define **Static Pods**
  🔸 No scheduler involved (yet)
      ↓
────────────────────────────────────────────
[3️⃣ kubelet reads /etc/kubernetes/manifests/]
  │
  ├─ Detects YAMLs placed by kubeadm
  ├─ Starts containers for:
  │     - etcd
  │     - kube-apiserver
  │     - kube-controller-manager
  │     - kube-scheduler
  └─ These run directly on the node (no API server interaction yet)
  🔹 **Static Pods are now running locally**
      ↓
────────────────────────────────────────────
[4️⃣ kube-apiserver becomes active (API Online)]
  │
  ├─ etcd (static pod) provides the key-value store
  ├─ kube-apiserver (static pod) connects to etcd and starts listening on port 6443
  ├─ kubelet periodically checks API health
  ├─ Once kubelet can reach API:
  │     - kubelet registers itself as a Node object
  │     - kubelet creates mirror pods in the API server for static pods
  └─ This marks the point where **kubelet knows the cluster is up**
  🔹 Cluster API is now functional — still only **Static Pods**
      ↓
────────────────────────────────────────────
[5️⃣ Controller Manager & Scheduler become active]
  │
  ├─ Both are **Static Pods**, but now they can connect to API server
  ├─ Controller Manager starts controlling cluster state:
  │     - Nodes
  │     - ReplicaSets
  │     - Deployments
  │     - DaemonSets
  ├─ Scheduler starts watching for pods without `nodeName`
  └─ Control Plane is fully functional using only **Static Pods**
      ↓
────────────────────────────────────────────
[6️⃣ Controller Manager exposes dynamic objects → kubeadm applies Add-ons]
  │
  ├─ kubeadm now triggers add-on installation:
  │     kubeadm init phase addon coredns
  │     kubeadm init phase addon kube-proxy
  │
  ├─ Using API Server, these manifests create:
  │     - CoreDNS → Deployment (🌀 **Dynamic Pods**)
  │     - kube-proxy → DaemonSet (🌀 **Dynamic Pods**)
  │     - CNI plugin (Calico/Canal/Flannel) → DaemonSet (🌀 **Dynamic Pods**)
  │
  ├─ The **Controller Manager** manages these objects
  ├─ The **Scheduler** assigns them to nodes
  └─ This is where **Dynamic Pods** are created — but only after the control plane (Static Pods) is fully running
  🔹 **Dynamic Pods start AFTER Static Pods make cluster operational**
      ↓
────────────────────────────────────────────
[7️⃣ Controllers & Scheduler manage workloads]
  │
  ├─ Controller Manager enforces desired state:
  │     - CoreDNS replica count
  │     - kube-proxy and CNI agents per node
  ├─ Scheduler assigns new pods to suitable nodes
  └─ kubelet on each node runs and reports pod status
  🔹 **Dynamic Pods now fully managed by the Control Plane**
      ↓
────────────────────────────────────────────
[✅ 8️⃣ Cluster Fully Functional]
  │
  ├─ **Static Pods:** etcd, kube-apiserver, kube-scheduler, kube-controller-manager
  ├─ **Dynamic Pods:** CoreDNS, kube-proxy, CNI, and user workloads
  └─ Scheduler continuously handles new workloads
```

---
