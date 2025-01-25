### **What Are QoS Classes?**
Kubernetes assigns pods a QoS class (**Guaranteed**, **Burstable**, or **BestEffort**) based on their resource `requests` and `limits`. This classification determines **eviction priority** when a node faces resource starvation (e.g., CPU/memory pressure) and influences scheduling decisions.

---

### **1. Guaranteed QoS**
#### **Mechanics**:
- **Requirements**:
  - *All* containers in the pod must have `limits` and `requests` explicitly defined.
  - `limits` must equal `requests` for **both CPU and memory** in every container.
- **Behavior**:
  - **Highest Priority**: Kubernetes protects these pods from eviction unless the node is catastrophically overcommitted.
  - **Resource Reservation**: The kubelet reserves the requested resources (CPU/memory) exclusively for the pod.
  - **OOM Killer Immunity**: The Linux Out-of-Memory (OOM) Killer is least likely to target these pods (lowest `oom_score`).

#### **Technical Nuances**:
- If you define only `limits` (no `requests`), Kubernetes automatically sets `requests = limits`, making the pod **Guaranteed**.
- **Use Case**: Critical stateful workloads (e.g., databases) where downtime is unacceptable.

---

### **2. Burstable QoS**
#### **Mechanics**:
- **Requirements**:
  - At least one container in the pod has:
    - `requests` < `limits` (for CPU or memory), **OR**
    - Only `requests` defined (no `limits`), **OR**
    - No resource constraints at all (but other containers have constraints).
- **Behavior**:
  - **Medium Priority**: Evicted before Guaranteed pods but after BestEffort.
  - **Resource Overcommit**: Can "burst" to use unused node resources but risks termination under pressure.
  - **Variable OOM Score**: Higher `oom_score` than Guaranteed pods but lower than BestEffort.

#### **Technical Nuances**:
- A pod with one container having `requests < limits` and others with `requests = limits` is **still Burstable**.
- **Use Case**: Stateless apps (e.g., web servers) needing baseline resources but tolerating occasional disruptions.

---

### **3. BestEffort QoS**
#### **Mechanics**:
- **Requirements**:
  - *No* container in the pod has `requests` or `limits` defined for CPU or memory.
- **Behavior**:
  - **Lowest Priority**: First to be evicted when resources are scarce.
  - **No Resource Guarantees**: Competes for leftover resources; can starve if the node is busy.
  - **OOM Killer Target**: Highest `oom_score`, making them prime candidates for termination.

#### **Technical Nuances**:
- BestEffort pods can monopolize idle resources but are "cannon fodder" during shortages.
- **Use Case**: Non-critical batch jobs (e.g., log processors) where failure is acceptable.

---

### **Deep Dive: How Eviction Works**
1. **Resource Pressure Detection**:
   - The kubelet monitors node resources (CPU, memory, disk, PID limits).
   - If memory/CPU exceeds thresholds, the kubelet triggers eviction.

2. **Eviction Order**:
   - **BestEffort** → **Burstable** → **Guaranteed**.
   - Within a QoS class, pods are ranked by their **consumption relative to requests**:
     - A Burstable pod using 90% of its memory `requests` is evicted before one using 150%.

3. **OOM Killer Interaction**:
   - Linux assigns an `oom_score` to each process. Kubernetes sets this score based on QoS:
     - **BestEffort**: `oom_score_adj = 1000`
     - **Burstable**: `oom_score_adj = 999 - (10 * % of memory requested)`
     - **Guaranteed**: `oom_score_adj = -998`
   - Lower scores = less likely to be killed.

---

### **Edge Cases & Gotchas**
1. **Multi-Container Pods**:
   - QoS is determined by the **strictest container**:
     - If one container is BestEffort, the entire pod is BestEffort.
     - If one container is Burstable, the pod is Burstable (even if others are Guaranteed).

2. **Resource Types Matter**:
   - **CPU**: A "compressible" resource. Pods are throttled, not killed, if they exceed CPU limits.
   - **Memory**: An "incompressible" resource. Exceeding memory limits triggers OOM kills.

3. **Scheduling vs. QoS**:
   - The scheduler uses `requests` to place pods on nodes with sufficient resources.
   - `limits` are enforced by the kubelet but do not affect scheduling.

4. **Namespace-Level Controls**:
   - **ResourceQuotas**: Enforce aggregate `requests/limits` per namespace.
   - **LimitRanges**: Set default `requests/limits` for pods in a namespace.

---

### **Real-World Scenarios**
1. **Cluster Overcommit**:
   - If a node’s total `requests` exceed its capacity, Burstable/BestEffort pods are at risk during spikes.
   - Example: A node with 4 CPU cores might have pods with total `requests` = 4 cores (Guaranteed) and `limits` = 8 cores (Burstable). Under load, Burstable pods are throttled or evicted.

2. **Debugging Evictions**:
   - Check `kubectl describe node` for `Allocated Resources` and `Conditions`.
   - Use `kubectl get events --field-selector=reason=Evicted` to find evicted pods.

3. **Horizontal Pod Autoscaling (HPA)**:
   - HPA scales based on `requests`, not `limits`. Misconfigured `requests` can lead to unstable scaling.

---

### **Best Practices**
1. **Guaranteed**:
   - Use for stateful, mission-critical apps.
   - Avoid overcommitting node resources to protect these pods.

2. **Burstable**:
   - Set `requests` to the app’s steady-state requirement.
   - Define `limits` to prevent runaway resource consumption.

3. **BestEffort**:
   - Avoid in production. Use only for trivial workloads.
   - Never mix BestEffort and Burstable/Guaranteed containers in the same pod.

---

### **Under the Hood**
- The kubelet writes QoS class metadata to `/etc/podinfo` in each container.
- Kubernetes uses the `cgroups` subsystem to enforce `limits` (e.g., `cpu.cfs_quota_us` for CPU, `memory.limit_in_bytes` for memory).

---

By mastering QoS, you ensure critical workloads survive resource contention while optimizing cluster efficiency. This balance is key to running resilient, cost-effective Kubernetes clusters. 🚀
