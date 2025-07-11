

## Kubernetes Cluster Upgrade Process: Detailed Notes

### Overview
Upgrading a Kubernetes cluster involves updating its core components to a newer version while ensuring minimal disruption to running workloads. This process is critical for maintaining security, accessing new features, and staying within Kubernetes' supported version range. The lecture focuses on:
- Version compatibility and skew policies for Kubernetes components, expressed as formulas (e.g., `x-1`, `x-2`, `x+1`).
- The necessity of upgrading one minor version at a time.
- Strategies for upgrading master and worker nodes.
- Using the `kubeadm` tool for planning and executing upgrades.
- Addressing whether a direct upgrade from 1.27 to 1.30 is possible.

### Kubernetes Components and Version Skew Policy
Kubernetes clusters consist of several core components:
- **Kube-API-Server**: The central control plane component that handles API requests and serves as the communication hub.
- **Kube-Controller-Manager**: Manages controllers to maintain the desired cluster state.
- **Kube-Scheduler**: Assigns pods to nodes based on resource requirements and scheduling policies.
- **Kubelet**: Runs on each node, managing pods and their containers.
- **Kube-Proxy**: Handles network connectivity for pods on each node.
- **Kubectl**: The command-line tool for interacting with the Kubernetes API.

#### Version Skew Policy with Formulas
The Kube-API-Server is the reference point for versioning, denoted as version `x`. The version skew policy ensures compatibility between components during upgrades. The permissible versions for other components relative to the Kube-API-Server (version `x`) are:

- **Kube-Controller-Manager and Kube-Scheduler**:
  - Can run at the same version as the Kube-API-Server (`x`) or one minor version lower (`x-1`).
  - Formula: `Version ∈ {x, x-1}`.
  - Example: If Kube-API-Server is at 1.30 (`x = 1.30`), these components can be at 1.30 or 1.29.

- **Kubelet and Kube-Proxy**:
  - Can run at the same version as the Kube-API-Server (`x`), one minor version lower (`x-1`), or two minor versions lower (`x-2`).
  - Formula: `Version ∈ {x, x-1, x-2}`.
  - Example: If Kube-API-Server is at 1.30 (`x = 1.30`), Kubelet and Kube-Proxy can be at 1.30, 1.29, or 1.28.

- **Kubectl**:
  - Can run at one minor version higher (`x+1`), the same version (`x`), or one minor version lower (`x-1`) than the Kube-API-Server.
  - Formula: `Version ∈ {x+1, x, x-1}`.
  - Example: If Kube-API-Server is at 1.30 (`x = 1.30`), Kubectl can be at 1.31, 1.30, or 1.29.

- **Key Constraint**: No component (except Kubectl) can run at a version higher than the Kube-API-Server (i.e., `x+1` is not allowed for Kube-Controller-Manager, Kube-Scheduler, Kubelet, or Kube-Proxy).

#### Example with Version 1.30
If the Kube-API-Server is at version 1.30 (`x = 1.30`):
- Kube-Controller-Manager and Kube-Scheduler: `Version ∈ {1.30, 1.29}`.
- Kubelet and Kube-Proxy: `Version ∈ {1.30, 1.29, 1.28}`.
- Kubectl: `Version ∈ {1.31, 1.30, 1.29}`.
- Invalid configurations: Kube-Controller-Manager at 1.31 or Kubelet at 1.27 (as 1.27 is `x-3`, which is not supported).

This version skew policy enables **live upgrades** by allowing components to be upgraded incrementally without breaking compatibility.

### When to Upgrade
Kubernetes supports the **latest three minor versions** at any given time. For example:
- If the latest version is **1.30**, the supported versions are **1.30**, **1.29**, and **1.28**.
- When **1.31** is released, support for **1.28** is dropped, and the supported versions become **1.31**, **1.30**, and **1.29**.

To avoid running an unsupported version, upgrade your cluster before a new minor version is released. For example:
- If your cluster is at **1.27** and **1.30** is the latest version, plan to upgrade to **1.28** or **1.29** before **1.31** is released to stay within the supported range.

### Is Direct Migration from 1.27 to 1.30 Possible?
**No**, direct migration from **1.27** to **1.30** is not supported. Kubernetes requires upgrades to proceed **one minor version at a time** to ensure stability and compatibility. Skipping minor versions (e.g., 1.27 to 1.30) can result in:
- **API Incompatibilities**: Deprecated APIs removed in later versions may break applications.
- **Component Mismatches**: Version skews beyond the supported range (`x-1`, `x-2`) can cause communication failures.
- **Upgrade Failures**: Unhandled changes in configuration or behavior may lead to cluster instability.

#### Recommended Upgrade Path
To upgrade from **1.27** to **1.30**, follow this sequence:
1. **1.27** → **1.28**
2. **1.28** → **1.29**
3. **1.29** → **1.30**

Each step involves upgrading the master node(s), then the worker nodes, and validating cluster stability before proceeding to the next minor version.

### Upgrade Process Overview
The upgrade process depends on the cluster deployment method:
- **Managed Kubernetes Clusters** (e.g., Google Kubernetes Engine, AWS EKS, Azure AKS): Upgrades are simplified through the cloud provider’s interface, often requiring minimal manual intervention.
- **Kubeadm-based Clusters**: The `kubeadm` tool provides commands to plan and execute upgrades systematically.
- **Manual Clusters (from scratch)**: Requires manually upgrading each component, which is complex and error-prone.

These notes focus on upgrading a **kubeadm-based cluster** from **1.27** to **1.28** as an example, incorporating the version skew formulas.

### Detailed Steps to Upgrade a Kubeadm-based Cluster
Upgrading a Kubernetes cluster involves two major phases:
1. **Upgrading the Master Node(s)**: Updates the control plane components (Kube-API-Server, Kube-Controller-Manager, Kube-Scheduler).
2. **Upgrading the Worker Node(s)**: Updates the Kubelet and Kube-Proxy on worker nodes.

#### Step 1: Upgrading the Master Node(s)
1. **Plan the Upgrade**:
   - Run `kubeadm upgrade plan` to gather critical information:
     - Current cluster version (e.g., 1.27).
     - Current `kubeadm` tool version.
     - Latest stable Kubernetes version (e.g., 1.28).
     - Current versions of control plane components and their upgrade targets.
   - Example output for upgrading from **1.27** to **1.28**:
     ```
     Current cluster version: 1.27
     Kubeadm version: 1.27
     Latest stable version: 1.28
     Component versions:
       - kube-apiserver: 1.27 -> 1.28 (x = 1.28)
       - kube-controller-manager: 1.27 -> 1.28 (x or x-1)
       - kube-scheduler: 1.27 -> 1.28 (x or x-1)
     Upgrade command: kubeadm upgrade apply v1.28
     Note: You must manually upgrade kubelet on each node (Version ∈ {x, x-1, x-2}).
     ```
   - The output confirms that after upgrading the control plane to `x = 1.28`, Kubelet can remain at 1.27 (`x-1`) or 1.26 (`x-2`).

2. **Upgrade the Kubeadm Tool**:
   - The `kubeadm` tool must be upgraded to the target version (`x = 1.28`) before upgrading the cluster.
   - On Debian/Ubuntu-based systems:
     ```bash
     sudo apt-get update
     sudo apt-get install -y kubeadm=1.28.x
     ```
   - Verify the version:
     ```bash
     kubeadm version
     ```

3. **Apply the Upgrade**:
   - Run the upgrade command provided by `kubeadm upgrade plan`:
     ```bash
     kubeadm upgrade apply v1.28
     ```
   - This command:
     - Pulls container images for version `x = 1.28`.
     - Upgrades control plane components to 1.28:
       - Kube-API-Server: `x = 1.28`.
       - Kube-Controller-Manager: `x = 1.28` (or remains at `x-1 = 1.27` temporarily).
       - Kube-Scheduler: `x = 1.28` (or remains at `x-1 = 1.27` temporarily).
     - Updates the cluster configuration.

4. **Upgrade Kubelet on the Master Node** (if applicable):
   - In `kubeadm` setups, master nodes often run Kubelet to host control plane components as pods.
   - Upgrade the Kubelet package to `x = 1.28` (or keep it at `x-1 = 1.27` or `x-2 = 1.26`, per the skew policy):
     ```bash
     sudo apt-get install -y kubelet=1.28.x
     ```
   - Restart the Kubelet service:
     ```bash
     sudo systemctl restart kubelet
     ```
   - Verify the master node version:
     ```bash
     kubectl get nodes
     ```
     - Note: The `kubectl get nodes` command displays the Kubelet version for each node, not the Kube-API-Server version. After upgrading, the master node’s Kubelet should be at `x = 1.28`.

5. **Impact During Master Node Upgrade**:
   - **Control Plane Downtime**: The control plane components (Kube-API-Server, Kube-Scheduler, Kube-Controller-Manager) are briefly unavailable during the upgrade.
   - **Workload Continuity**: Worker nodes and their pods continue to serve user traffic, as they operate independently of the control plane.
   - **Management Limitations**:
     - `kubectl` commands (e.g., deploy, delete, modify resources) are unavailable.
     - If a pod fails, the Kube-Controller-Manager won’t reschedule it until the control plane is back online.
   - **Post-Upgrade State**: The master node is at `x = 1.28`, while worker nodes remain at `x-1 = 1.27` or `x-2 = 1.26`, which is a supported configuration per the version skew policy.

#### Step 2: Upgrading the Worker Node(s)
Worker nodes must be upgraded to minimize application downtime. Three strategies are available:

1. **Upgrade All Nodes at Once**:
   - Drain all worker nodes, upgrade them simultaneously, and bring them back online.
   - **Process**:
     - Drain all nodes:
       ```bash
       kubectl drain <node-name> --ignore-daemonsets
       ```
     - Upgrade Kubeadm and Kubelet on all nodes to `x = 1.28`:
       ```bash
       sudo apt-get install -y kubeadm=1.28.x kubelet=1.28.x
       kubeadm upgrade node
       sudo systemctl restart kubelet
       ```
     - Uncordon all nodes:
       ```bash
       kubectl uncordon <node-name>
       ```
   - **Impact**: Causes downtime, as all pods are evicted, and no new pods are scheduled until the upgrade is complete.
   - **Pros**: Faster upgrade process.
   - **Cons**: Not suitable for production environments due to downtime.

2. **Upgrade One Node at a Time** (Recommended for Production):
   - Upgrade each worker node sequentially, moving workloads to other nodes during the process.
   - **Steps for Each Node**:
     - **Drain the Node**:
       ```bash
       kubectl drain <node-name> --ignore-daemonsets
       ```
       - Evicts all pods and reschedules them on other nodes.
       - Marks the node as unschedulable (cordoned) to prevent new pods from being scheduled.
     - **Upgrade Kubeadm and Kubelet**:
       ```bash
       sudo apt-get update
       sudo apt-get install -y kubeadm=1.28.x kubelet=1.28.x
       ```
     - **Update Node Configuration**:
       ```bash
       kubeadm upgrade node
       ```
     - **Restart Kubelet**:
       ```bash
       sudo systemctl restart kubelet
       ```
     - **Uncordon the Node**:
       ```bash
       kubectl uncordon <node-name>
       ```
       - Makes the node schedulable again. Pods may not immediately return unless other nodes are drained or new pods are created.
     - Repeat for each worker node (e.g., Node 1, Node 2, Node 3).
   - **Impact**:
     - Workloads are shifted to other nodes, ensuring application availability (assuming sufficient cluster capacity).
     - Example: When upgrading Node 1, pods move to Nodes 2 and 3. After Node 1 is upgraded, upgrade Node 2, with pods moving to Nodes 1 and 3, and so on.
   - **Pros**: Minimizes downtime, ideal for production environments.
   - **Cons**: Slower, as nodes are upgraded sequentially.
   - **Version Skew**: During the process, worker nodes may run Kubelet at `x-1 = 1.27` or `x-2 = 1.26` while the control plane is at `x = 1.28`, which is supported.

3. **Add New Nodes with the New Version**:
   - Add new worker nodes running the target version (`x = 1.28`), move workloads to them, and decommission old nodes.
   - **Steps**:
     - Provision new nodes with Kubernetes version `x = 1.28`.
     - Join new nodes to the cluster:
       ```bash
       kubeadm join <control-plane-endpoint> --token <token>
       ```
     - Drain old nodes to move workloads to new nodes:
       ```bash
       kubectl drain <old-node-name> --ignore-daemonsets
       ```
     - Delete old nodes:
       ```bash
       kubectl delete node <old-node-name>
       ```
   - **Impact**: No downtime, as new nodes take over workloads before old nodes are removed.
   - **Pros**: Seamless for cloud environments where provisioning new nodes is easy.
   - **Cons**: Requires additional resources and is more complex to manage.
   - **Version Skew**: New nodes run at `x = 1.28`, while old nodes may remain at `x-1 = 1.27` or `x-2 = 1.26` until decommissioned, which is supported.

4. **Post-Upgrade Verification**:
   - After upgrading all nodes, verify the cluster state:
     ```bash
     kubectl get nodes
     ```
     - All nodes should show Kubelet versions at `x = 1.28` (or `x-1 = 1.27` or `x-2 = 1.26` temporarily, per the skew policy).
   - Check pod status:
     ```bash
     kubectl get pods --all-namespaces
     ```

#### Repeating the Process
To reach **1.30** from **1.27**, repeat the above steps for each minor version:
- **1.27** → **1.28**: Upgrade master node(s) to `x = 1.28`, then worker nodes to `x = 1.28` (or keep at `x-1 = 1.27` or `x-2 = 1.26`).
- **1.28** → **1.29**: Upgrade master node(s) to `x = 1.29`, then worker nodes to `x = 1.29` (or keep at `x-1 = 1.28` or `x-2 = 1.27`).
- **1.29** → **1.30**: Upgrade master node(s) to `x = 1.30`, then worker nodes to `x = 1.30` (or keep at `x-1 = 1.29` or `x-2 = 1.28`).

### Key Considerations
- **Backup Critical Data**:
  - Before upgrading, back up etcd (e.g., using `etcdctl snapshot save`) and persistent volumes to prevent data loss.
- **Test in a Staging Environment**:
  - Perform upgrades in a non-production environment to identify issues, especially with deprecated APIs or custom configurations.
- **Deprecated APIs**:
  - Check the Kubernetes documentation for API deprecations/removals in the target version (e.g., 1.28).
  - Use `kubectl convert` to update manifests if necessary.
- **High Availability (HA) Clusters**:
  - In HA setups with multiple master nodes, upgrade one master at a time to maintain control plane availability.
  - Ensure the Kube-API-Server version remains consistent across master nodes after each upgrade.
- **External Components**:
  - Components like etcd and CoreDNS are not managed by `kubeadm` and must be upgraded separately, ensuring compatibility with Kubernetes version `x`.
- **Monitoring Cluster Health**:
  - After each upgrade step, verify:
    ```bash
    kubectl get nodes
    kubectl get pods --all-namespaces
    ```
  - Ensure all components adhere to the version skew policy (e.g., Kubelet ∈ {x, x-1, x-2}).
- **Kubectl Compatibility**:
  - Ensure the `kubectl` version is within the supported range (`x+1`, `x`, `x-1`) to avoid command failures.
- **Downtime Management**:
  - Use the “one node at a time” or “add new nodes” strategy for production clusters to avoid downtime.
  - Ensure sufficient cluster capacity to handle pod rescheduling during node drains.

### Example Workflow for Upgrading from 1.27 to 1.28
1. **Check Current Cluster State**:
   ```bash
   kubectl get nodes
   kubeadm upgrade plan
   ```
   - Confirms Kube-API-Server at `x = 1.27`, Kubelet versions at `x`, `x-1`, or `x-2`.

2. **Upgrade Kubeadm Tool**:
   ```bash
   sudo apt-get update
   sudo apt-get install -y kubeadm=1.28.x
   kubeadm version
   ```

3. **Upgrade Master Node**:
   ```bash
   kubeadm upgrade apply v1.28
   sudo apt-get install -y kubelet=1.28.x
   sudo systemctl restart kubelet
   kubectl get nodes
   ```
   - Control plane is now at `x = 1.28`, Kubelet on master at `x = 1.28`.

4. **Upgrade Worker Nodes (One at a Time)**:
   ```bash
   kubectl drain <node-name> --ignore-daemonsets
   sudo apt-get install -y kubeadm=1.28.x kubelet=1.28.x
   kubeadm upgrade node
   sudo systemctl restart kubelet
   kubectl uncordon <node-name>
   ```
   - Repeat for each worker node.
   - Worker nodes transition to `x = 1.28`, though some may remain at `x-1 = 1.27` or `x-2 = 1.26` temporarily.

5. **Verify Upgrade**:
   ```bash
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```
   - Ensure all nodes are at `x = 1.28` or within the supported skew (`x-1`, `x-2`).


### Conclusion
Upgrading a Kubernetes cluster is a systematic process that requires careful planning to maintain compatibility and minimize disruption. The version skew policy (`x`, `x-1`, `x-2` for components, `x+1`, `x`, `x-1` for Kubectl) ensures safe incremental upgrades. Direct migration from 1.27 to 1.30 is not supported; instead, upgrade one minor version at a time (1.27 → 1.28 → 1.29 → 1.30). Using `kubeadm`, administrators can upgrade master nodes first, followed by worker nodes, employing strategies like “one node at a time” or “add new nodes” to avoid downtime. By adhering to these steps and validating each stage, a Kubernetes cluster can be upgraded reliably to stay current and secure.

---

These notes provide a deep, accurate, and comprehensive guide to the Kubernetes cluster upgrade process, explicitly incorporating the version skew formulas (`x-1`, `x-2`, `x+1`) and addressing the direct migration question. Let me know if you need further clarification, additional examples, or assistance with specific upgrade scenarios!
