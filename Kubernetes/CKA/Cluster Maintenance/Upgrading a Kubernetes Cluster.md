

## Notes for Upgrading a Kubernetes Cluster with Kubeadm (1.28 to 1.29)

### Overview
- **Objective**: Upgrade a Kubernetes cluster from version 1.28 to 1.29 using `kubeadm`, following the official Kubernetes documentation.
- **Cluster Setup**: Example uses a two-node cluster (one control plane node, one worker node), but the process applies to clusters of any size.
- **Key Tools**:
  - `kubeadm`: Manages cluster lifecycle, including upgrades.
  - `kubectl`: CLI for interacting with the Kubernetes API.
  - `kubelet`: Node agent managing pods and containers.
- **Documentation**: Kubernetes documentation under *Tasks > Administer a Cluster > Administration with kubeadm > Upgrading kubeadm clusters* provides version-specific instructions.
- **Critical Update**: Package repositories have changed from `apt.kubernetes.io`/`yum.kubernetes.io` to `packages.k8s.io`, requiring updates to access the latest Kubernetes components.

---

### Step-by-Step Notes with Explanations

#### 1. Update Package Repositories (All Nodes)
**Notes**:
- **Command**:
  ```bash
  sudo apt-get install -y apt-transport-https ca-certificates curl
  sudo curl -fsSLo /etc/apt/keyrings/kubernetes-archive-keyring.gpg https://packages.k8s.io/keyrings/kubernetes-archive-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://packages.k8s.io/debian/v1.29 stable main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
  sudo apt-get update
  ```
- **Apply to**: All nodes (control plane and worker nodes).
- **Verification**: Ensure the repository file (`/etc/apt/sources.list.d/kubernetes.list`) exists and points to `packages.k8s.io/debian/v1.29`.

**Explanation**:
- **Purpose**: Kubernetes has deprecated old repositories (`apt.kubernetes.io`). The new `packages.k8s.io` repository ensures access to the latest versions of `kubeadm`, `kubectl`, and `kubelet`.
- **Why It’s Needed**: Without updating the repository, nodes cannot download version 1.29 components, leading to upgrade failures.
- **Technical Details**:
  - `apt-transport-https`, `ca-certificates`, and `curl` ensure secure package downloads.
  - The `curl` command fetches the public signing key to verify package authenticity.
  - The `echo` command creates a repository configuration file, specifying the 1.29 minor version.
  - `apt-get update` refreshes the package cache to include 1.29 components.
- **Pitfalls**:
  - Ensure the minor version (`v1.29`) matches the target upgrade version.
  - Apply to all nodes to avoid version mismatches.
  - Check for typos in the repository URL or keyring path.

#### 2. Determine the Target Version
**Notes**:
- **Commands**:
  ```bash
  sudo apt-get update
  apt-cache madison kubeadm | grep 1.29
  ```
- **Output**: Lists available `kubeadm` versions (e.g., `1.29.3-1.1` is the latest).
- **Action**: Note the exact version (e.g., `1.29.3-1.1`) for use in subsequent steps.

**Explanation**:
- **Purpose**: Identify the latest patch version within the 1.29 minor release to ensure the cluster uses the most stable and secure version.
- **Why It’s Needed**: Kubernetes releases patch versions (e.g., 1.29.0, 1.29.1, 1.29.3) with bug fixes and security updates. Selecting the latest ensures optimal performance.
- **Technical Details**:
  - `apt-cache madison kubeadm` queries the package cache for available `kubeadm` versions.
  - The `grep 1.29` filter narrows results to the 1.29 minor release.
  - The latest version (e.g., `1.29.3-1.1`) is typically at the top of the output.
- **Pitfalls**:
  - Ensure `apt-get update` is run first to refresh the cache.
  - Double-check the version to avoid installing an outdated patch.

#### 3. Upgrade the Control Plane Node
**Notes**:
- **Steps**:
  1. **Upgrade `kubeadm`**:
     ```bash
     sudo apt-get install -y kubeadm=1.29.3-1.1
     kubeadm version
     ```
  2. **Run Upgrade Plan**:
     ```bash
     sudo kubeadm upgrade plan
     ```
  3. **Apply Upgrade**:
     ```bash
     sudo kubeadm upgrade apply v1.29.3
     ```
  4. **Drain Node**:
     ```bash
     kubectl drain control-plane --ignore-daemonsets
     ```
  5. **Upgrade `kubelet` and `kubectl`**:
     ```bash
     sudo apt-get install -y kubelet=1.29.3-1.1 kubectl=1.29.3-1.1
     sudo systemctl restart kubelet
     ```
  6. **Uncordon Node**:
     ```bash
     kubectl uncordon control-plane
     ```
  7. **Verify**:
     ```bash
     kubectl get nodes
     ```

**Explanation**:
- **Purpose**: Upgrade the control plane node, which hosts critical components (API server, controller manager, scheduler) to version 1.29.3.
- **Why It’s Needed**: The control plane must be upgraded first to ensure the cluster’s core services support the new version before worker nodes are updated.
- **Technical Details**:
  - **Upgrade `kubeadm`**: Installs the 1.29.3 version of `kubeadm`, enabling it to manage the 1.29 cluster upgrade. Verify with `kubeadm version`.
  - **Upgrade Plan**: A dry-run command that checks compatibility, lists components `kubeadm` will upgrade (e.g., API server), and identifies manual upgrades (e.g., `kubelet`).
  - **Apply Upgrade**: Updates control plane components to 1.29.3. The `kubectl get nodes` output may still show 1.28.0 because `kubelet` isn’t yet upgraded.
  - **Drain Node**: Evicts pods (e.g., CoreDNS) to prevent disruptions during `kubelet` upgrade. `--ignore-daemonsets` ensures daemonset pods (e.g., networking agents) remain.
  - **Upgrade `kubelet`/`kubectl`**: Installs 1.29.3 versions and restarts `kubelet` to apply changes. `kubectl` is optional but recommended for consistency.
  - **Uncordon Node**: Re-enables scheduling so pods can run on the node again.
  - **Verification**: `kubectl get nodes` should show 1.29.3 for the control plane node.
- **Pitfalls**:
  - If `kubectl get nodes` shows 1.28.0 after `upgrade apply`, it’s due to `kubelet` not being upgraded (normal behavior).
  - Ensure `drain` and `uncordon` are executed to avoid scheduling issues.
  - For multiple control plane nodes, use `kubeadm upgrade node` instead of `upgrade apply` for additional nodes.

#### 4. Upgrade Worker Nodes
**Notes**:
- **Steps**:
  1. **Upgrade `kubeadm`**:
     ```bash
     sudo apt-get install -y kubeadm=1.29.3-1.1
     ```
  2. **Run Upgrade Node**:
     ```bash
     sudo kubeadm upgrade node
     ```
  3. **Drain Node**:
     ```bash
     kubectl drain node-01 --ignore-daemonsets
     ```
  4. **Upgrade `kubelet` and `kubectl`**:
     ```bash
     sudo apt-get install -y kubelet=1.29.3-1.1 kubectl=1.29.3-1.1
     sudo systemctl restart kubelet
     ```
  5. **Uncordon Node**:
     ```bash
     kubectl uncordon node-01
     ```
  6. **Verify**:
     ```bash
     kubectl get nodes
     ```
  7. **Repeat**: For each worker node.

**Explanation**:
- **Purpose**: Upgrade worker nodes to 1.29.3 to align with the control plane.
- **Why It’s Needed**: Worker nodes run application workloads and must match the control plane’s version for compatibility.
- **Technical Details**:
  - **Upgrade `kubeadm`**: Ensures the worker node has the 1.29.3 version of `kubeadm`.
  - **Upgrade Node**: Applies node-specific upgrades (less extensive than control plane upgrades).
  - **Drain Node**: Run from the control plane to evict pods, ensuring no workload disruptions.
  - **Upgrade `kubelet`/`kubectl`**: Updates `kubelet` to 1.29.3; `kubectl` is optional on worker nodes. Restart `kubelet` to apply changes.
  - **Uncordon Node**: Re-enables scheduling.
  - **Verification**: `kubectl get nodes` confirms the worker node is at 1.29.3.
- **Pitfalls**:
  - Run `drain` from the control plane, not the worker node.
  - Upgrade nodes sequentially to maintain cluster availability.
  - Ensure `kubectl` is installed only if needed on worker nodes.

#### 5. Additional Steps
**Notes**:
- **CNI Plugin Check**:
  - Verify if the Container Network Interface (CNI) plugin (e.g., Calico, Flannel) requires an update for 1.29 compatibility.
  - If needed, follow the CNI provider’s documentation to upgrade.
- **Multiple Control Plane Nodes**:
  - For additional control plane nodes:
    ```bash
    sudo apt-get install -y kubeadm=1.29.3-1.1
    sudo kubeadm upgrade node
    kubectl drain <node-name> --ignore-daemonsets
    sudo apt-get install -y kubelet=1.29.3-1.1 kubectl=1.29.3-1.1
    sudo systemctl restart kubelet
    kubectl uncordon <node-name>
    ```
- **Verification**:
  - `kubectl get nodes`: All nodes should show 1.29.3.
  - `kubeadm version`: Confirms `kubeadm` version.
  - `kubectl version`: Confirms `kubectl` version.

**Explanation**:
- **CNI Plugin**: Some CNI plugins require updates to support new Kubernetes versions. Skipping this step (as in the transcript) assumes compatibility.
- **Multiple Control Planes**: The `upgrade node` command is used for additional control plane nodes to avoid reapplying control plane-wide changes.
- **Verification**: Ensures the entire cluster is consistently running 1.29.3, with no version mismatches.

---

### Key Considerations
- **Order**: Upgrade control plane nodes first, then worker nodes, to maintain cluster stability.
- **Manual `kubelet` Upgrade**: `kubeadm` does not manage `kubelet`, requiring manual upgrades on each node.
- **Draining/Uncordon**: Prevents workload disruptions and re-enables scheduling post-upgrade.
- **Repository Consistency**: All nodes must use `packages.k8s.io` to avoid version conflicts.
- **Scalability**: The process is identical for multi-node clusters; upgrade nodes one at a time to avoid downtime.
- **CNI Compatibility**: Always check CNI provider documentation for version-specific requirements.

---

### Common Commands for Reference
- **Check OS**: `cat /etc/*release*`
- **List Versions**: `apt-cache madison kubeadm | grep 1.29`
- **Update Packages**: `sudo apt-get update`
- **Install Specific Version**: `sudo apt-get install -y <package>=<version>`
- **Restart `kubelet`**: `sudo systemctl restart kubelet`
- **Drain Node**: `kubectl drain <node-name> --ignore-daemonsets`
- **Uncordon Node**: `kubectl uncordon <node-name>`
- **Verify Cluster**: `kubectl get nodes`
- **Verify Tool Versions**: `kubeadm version`, `kubectl version`

---

### Troubleshooting Tips
- **Version Mismatch**:
  - If `kubectl get nodes` shows 1.28.0 after `upgrade apply`, verify `kubelet` is upgraded and restarted.
  - Check `kubeadm version` and `kubectl version` for consistency.
- **Repository Issues**:
  - Verify `/etc/apt/sources.list.d/kubernetes.list` points to `packages.k8s.io/debian/v1.29`.
  - Ensure the signing key is correctly installed (`/etc/apt/keyrings/kubernetes-archive-keyring.gpg`).
- **Node Scheduling Issues**:
  - If nodes remain unschedulable, confirm `kubectl uncordon` was run.
  - Check for errors in `kubectl describe node <node-name>`.
- **CNI Problems**:
  - If networking issues arise post-upgrade, verify the CNI plugin version and compatibility.
- **Upgrade Failures**:
  - Review `kubeadm upgrade plan` output for compatibility issues.
  - Check logs: `journalctl -u kubelet` or `kubectl logs` for control plane components.

---

### Example Workflow Summary
1. **Update Repositories**:
   - On all nodes: Configure `packages.k8s.io` for 1.29, run `apt-get update`.
2. **Identify Version**:
   - Use `apt-cache madison kubeadm` to select `1.29.3-1.1`.
3. **Control Plane Upgrade**:
   - Upgrade `kubeadm`, run `upgrade plan`, apply `upgrade apply v1.29.3`.
   - Drain node, upgrade `kubelet`/`kubectl`, restart `kubelet`, uncordon node.
4. **Worker Node Upgrade**:
   - Upgrade `kubeadm`, run `upgrade node`.
   - Drain node, upgrade `kubelet`/`kubectl`, restart `kubelet`, uncordon node.
   - Repeat for each worker node.
5. **Verify**:
   - `kubectl get nodes` shows all nodes at 1.29.3.
   - Check CNI plugin if needed.

---

This set of notes, with integrated explanations, provides a clear and actionable guide for upgrading a Kubernetes cluster using `kubeadm`. Each step is detailed with its purpose, technical rationale, and potential issues to watch for, making it suitable for both execution and learning. If you need further clarification, specific command outputs, or additional troubleshooting steps, let me know!
