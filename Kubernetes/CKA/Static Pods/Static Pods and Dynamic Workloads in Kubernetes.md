# 📘 Simplified Deep Notes: Static Pods and Dynamic Workloads in Kubernetes

---

## 🧠 The Big Picture: How Kubernetes Starts and Runs Pods

When you set up a Kubernetes cluster using `kubeadm`, it starts with **static pods** to bootstrap the core components (like `kube-apiserver` and `etcd`). Once these are running, the control plane becomes active, enabling **dynamic workloads** (like `coredns` and `kube-flannel`) to be created. The confusion often comes from the sequence of events and why some pods are "static" while others are not. Let’s break it down step-by-step.

---

## 🚀 Step-by-Step: How a Cluster Starts with `kubeadm`

### 1. Before `kubeadm init`: No Cluster Exists
- You have a bare node with **Kubelet** (a node agent) and a container runtime (e.g., `containerd`).
- No control plane (no API server, scheduler, or etcd) exists yet.
- The Kubelet can still run **static pods** using local YAML files in a special directory (`/etc/kubernetes/manifests/`).

### 2. Running `kubeadm init`: Bootstrapping the Control Plane
When you run `kubeadm init`:
- **Kubeadm** creates YAML manifest files for the core control plane components in `/etc/kubernetes/manifests/`:
  - `etcd.yaml`: Runs the `etcd` data store.
  - `kube-apiserver.yaml`: Runs the API server for cluster communication.
  - `kube-controller-manager.yaml`: Runs controllers to manage workloads.
  - `kube-scheduler.yaml`: Schedules pods to nodes.
- The **Kubelet** reads these files and starts these as **static pods** locally on the node.
- **Why Static Pods?** They don’t need an API server to run, allowing the control plane to bootstrap itself.

### 3. Static Pods Bring the Control Plane to Life
- The Kubelet starts the static pods:
  - `etcd-controlplane`: Stores cluster data.
  - `kube-apiserver-controlplane`: Provides the API for cluster management.
  - `kube-controller-manager-controlplane`: Manages controllers (e.g., for Deployments, DaemonSets).
  - `kube-scheduler-controlplane`: Assigns pods to nodes.
- Once `kube-apiserver` is running, the cluster’s control plane is active, and you can use `kubectl` to interact with the cluster.
- The Kubelet registers these static pods as **mirror pods** in the `kube-system` namespace, visible via:
  ```bash
  kubectl get pods -n kube-system
  ```
  Example output:
  ```
  etcd-controlplane                    1/1     Running   0          2m
  kube-apiserver-controlplane          1/1     Running   0          2m
  kube-controller-manager-controlplane  1/1     Running   0          2m
  kube-scheduler-controlplane          1/1     Running   0          2m
  ```

### 4. Control Plane Enables Dynamic Workloads
- With the API server and other components running, `kubeadm` applies additional manifests for **dynamic workloads**:
  - **CoreDNS** (Deployment): Runs DNS for service discovery.
  - **Kube-Proxy** (DaemonSet): Manages network rules for services.
- These are **not static pods** because they are created via the API server and managed by the control plane (scheduler and controller manager).
- You also apply a networking plugin (e.g., Flannel) as a DaemonSet to enable pod-to-pod communication:
  ```bash
  kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
  ```
- These pods appear in `kube-system` alongside static pods:
  ```
  coredns-XXX                          1/1     Running   0          2m
  kube-flannel-ds-XXX                  1/1     Running   0          2m
  kube-proxy-XXX                       1/1     Running   0          2m
  ```

---

## 🧩 Why the Confusion? Static Pods vs. Dynamic Workloads

### Static Pods
- **What**: Pods managed by the Kubelet using local YAML files in `/etc/kubernetes/manifests/`.
- **When**: Created during `kubeadm init` to bootstrap the control plane.
- **Why**: They run without an API server, enabling the cluster to start.
- **Examples**: `etcd`, `kube-apiserver`, `kube-controller-manager`, `kube-scheduler`.
- **Key Trait**: You can’t edit/delete them with `kubectl` (modify the YAML files instead).

### Dynamic Workloads
- **What**: Pods managed by the control plane (API server, scheduler, controllers) via Deployments or DaemonSets.
- **When**: Created after the control plane is running, either by `kubeadm` or manually (e.g., Flannel).
- **Why**: They rely on the API server and provide cluster-wide services (DNS, networking).
- **Examples**: `coredns` (Deployment), `kube-flannel` (DaemonSet), `kube-proxy` (DaemonSet).
- **Key Trait**: Created/edited via `kubectl apply` and stored in `etcd`.

### Why They’re in `kube-system` Together
- Both static pods (as mirror pods) and dynamic workloads run in the `kube-system` namespace because they’re system-level components.
- Static pods appear as mirror pods once the API server is up, but they’re still managed by the Kubelet.

---

## 🧱 Summary Table

| **Component**                | **Static Pod?** | **Managed By**                     | **YAML Source**                              | **When Created**                     |
|------------------------------|-----------------|------------------------------------|----------------------------------------------|--------------------------------------|
| `kube-apiserver`             | ✅ Yes          | Kubelet (local)                   | `/etc/kubernetes/manifests/`                | During `kubeadm init`                |
| `etcd`                       | ✅ Yes          | Kubelet (local)                   | `/etc/kubernetes/manifests/`                | During `kubeadm init`                |
| `kube-controller-manager`    | ✅ Yes          | Kubelet (local)                   | `/etc/kubernetes/manifests/`                | During `kubeadm init`                |
| `kube-scheduler`             | ✅ Yes          | Kubelet (local)                   | `/etc/kubernetes/manifests/`                | During `kubeadm init`                |
| `coredns`                    | ❌ No           | Deployment + ReplicaSet Controller | `kubectl apply` (kubeadm add-ons)           | After control plane is up            |
| `kube-flannel`               | ❌ No           | DaemonSet Controller               | `kubectl apply` (Flannel manifest)          | After control plane, via user action |
| `kube-proxy`                 | ❌ No           | DaemonSet Controller               | `kubectl apply` (kubeadm add-ons)           | After control plane is up            |

---

## 🛠️ Recreation Notes: Set Up a Cluster to See This in Action

To clarify the process and observe static pods and dynamic workloads, set up a single-node Kubernetes cluster with `kubeadm`. This will replicate the scenario where static pods bootstrap the control plane, followed by dynamic workloads.

### Prerequisites
- **OS**: Ubuntu 20.04/22.04.
- **Hardware**: 2 CPUs, 2GB RAM, 20GB disk (e.g., a VM).
- **Tools**: `kubeadm`, `kubectl`, `kubelet`, `containerd`.

### Step-by-Step Guide
#### 1. Install Dependencies
```bash
# Update system
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

# Install containerd
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd

# Add Kubernetes repository
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/kubernetes.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes tools
sudo apt-get update
sudo apt-get install -y kubeadm=1.29.0-00 kubelet=1.29.0-00 kubectl=1.29.0-00
sudo apt-mark hold kubeadm kubelet kubectl
```

#### 2. Initialize the Cluster
Run `kubeadm init` to create a single-node cluster:
```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

- **What Happens**:
  1. `kubeadm` creates static pod manifests in `/etc/kubernetes/manifests/` for `etcd`, `kube-apiserver`, `kube-controller-manager`, and `kube-scheduler`.
  2. Kubelet starts these as static pods, bootstrapping the control plane.
  3. `kubeadm` applies manifests for `kube-proxy` (DaemonSet) and `coredns` (Deployment) via the API server.

- **Post-Init**:
  - Set up `kubectl`:
    ```bash
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    ```
  - Verify static pods:
    ```bash
    kubectl get pods -n kube-system
    ```
    Expected output:
    ```
    NAME                                       READY   STATUS    RESTARTS   AGE
    coredns-XXX                                0/1     Pending   0          2m
    etcd-controlplane                          1/1     Running   0          2m
    kube-apiserver-controlplane                1/1     Running   0          2m
    kube-controller-manager-controlplane       1/1     Running   0          2m
    kube-proxy-XXX                             1/1     Running   0          2m
    kube-scheduler-controlplane                1/1     Running   0          2m
    ```
    (Note: `coredns` may be `Pending` until networking is set up.)

#### 3. Install Flannel (Networking)
Apply the Flannel DaemonSet to enable pod networking:
```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

- Verify:
  ```bash
  kubectl get pods -n kube-system | grep flannel
  ```
  Expected output:
  ```
  kube-flannel-ds-XXX                        1/1     Running   0          1m
  ```
- `coredns` pods should now be `Running`:
  ```bash
  kubectl get pods -n kube-system
  ```

#### 4. Inspect Static Pods
Check the manifest directory:
```bash
ls /etc/kubernetes/manifests/
```
Output:
```
etcd.yaml  kube-apiserver.yaml  kube-controller-manager.yaml  kube-scheduler.yaml
```

View a manifest (e.g., `kube-apiserver.yaml`):
```bash
cat /etc/kubernetes/manifests/kube-apiserver.yaml
```

#### 5. Test a Custom Static Pod
Create a static pod to see Kubelet’s behavior:
```bash
sudo tee /etc/kubernetes/manifests/nginx-static.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx-static
  namespace: kube-system
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
EOF
```

- Verify:
  ```bash
  kubectl get pods -n kube-system | grep nginx
  ```
  Expected output:
  ```
  nginx-static-<nodename>                    1/1     Running   0          10s
  ```

- Modify or Delete:
  - Edit `nginx-static.yaml` (e.g., change image to `nginx:1.26`) to see Kubelet restart the pod.
  - Delete the file to remove the pod:
    ```bash
    sudo rm /etc/kubernetes/manifests/nginx-static.yaml
    ```

#### 6. Test a DaemonSet
Create a simple DaemonSet:
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nginx-daemonset
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
```

Apply it:
```bash
kubectl apply -f nginx-daemonset.yaml
```

Verify:
```bash
kubectl get pods -n kube-system | grep nginx-daemonset
```

---

## 🔍 Clarifying the Sequence
1. **No Cluster**: Kubelet is ready but idle.
2. **kubeadm init**:
   - Creates static pod manifests for control plane components.
   - Kubelet starts `etcd`, `kube-apiserver`, etc., as static pods.
3. **Control Plane Up**: API server and scheduler become available.
4. **Dynamic Workloads**:
   - `kubeadm` applies `coredns` (Deployment) and `kube-proxy` (DaemonSet).
   - You apply `kube-flannel` (DaemonSet) manually.
5. **Result**: `kubectl get pods -n kube-system` shows static pods (as mirror pods) and dynamic workload pods.

---

## 🛠️ Troubleshooting Tips
- **Static Pods Not Running**:
  - Check Kubelet logs: `journalctl -u kubelet`.
  - Ensure `/etc/kubernetes/manifests/` files are readable (`chmod 644`).
- **Dynamic Pods Pending**:
  - Verify networking (e.g., Flannel) is applied.
  - Check pod logs: `kubectl logs -n kube-system coredns-XXX`.
- **API Server Issues**:
  - Inspect `kube-apiserver` manifest for correct flags.
  - Check `etcd` health: `kubectl exec -n kube-system etcd-controlplane -- etcdctl endpoint health`.

---

## 📄 Exporting Notes
- **Markdown**: Copy these notes into a `.md` file.
- **PDF**: Use `pandoc`:
  ```bash
  pandoc static-pods-notes.md -o static-pods-notes.pdf
  ```

---

## ❓ Next Steps
Let me know if you need:
- A deeper dive into a specific manifest (e.g., Flannel’s YAML).
- Help with a multi-node setup.
- More examples of static pods or DaemonSets.
- Clarification on any specific step or concept.

These notes simplify the process, emphasize the sequence, and provide hands-on steps to recreate the setup. I hope this clears up the confusion!
