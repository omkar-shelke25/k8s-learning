
---

### **1. Core Concepts**
#### **Requests**
- **Purpose**: Guarantee a minimum amount of resources (CPU/memory) to a container.
- **Scheduling**: The Kubernetes scheduler uses `requests` to select a node with sufficient resources to run the pod. For example:
  - If a pod requests `500m` CPU and `1Gi` memory, the scheduler ensures the node has at least that much allocatable capacity.
- **Resource Reservation**: The node "reserves" the requested resources exclusively for the pod, even if the pod isn’t fully utilizing them.

#### **Limits**
- **Purpose**: Enforce a maximum cap on resource usage.
- **Enforcement**:
  - **CPU**: If a container exceeds its CPU limit, it is **throttled** (i.e., CPU time is restricted).
  - **Memory**: If a container exceeds its memory limit, it is **terminated** (OOM-killed) and potentially rescheduled.

---

### **2. Why Limits Must Be ≥ Requests**
#### **CPU**
- **Scenario**: If `limit < request`:
  - The scheduler places the pod on a node with enough CPU to satisfy the `request`.
  - The container is **throttled** if it uses more than the `limit`, even if the node has idle CPU.
  - **Result**: The pod is guaranteed resources it cannot fully use, leading to wasted capacity and poor performance.

#### **Memory**
- **Scenario**: If `limit < request`:
  - The scheduler places the pod on a node with enough memory to satisfy the `request`.
  - The container is **terminated** if it uses more than the `limit`, even if the node has free memory.
  - **Result**: The pod is guaranteed memory it cannot safely use, leading to crashes and instability.

---

### **3. Quality of Service (QoS) Classes**
Kubernetes assigns pods to one of three QoS classes based on resource configurations:
1. **Guaranteed**:
   - `limits == requests` for all resources.
   - Highest priority; least likely to be evicted under resource pressure.
2. **Burstable**:
   - `limits > requests` (or only `requests` are set).
   - Medium priority; evicted before `Guaranteed` pods.
3. **BestEffort**:
   - No `requests` or `limits` defined.
   - Lowest priority; first to be evicted.

**Example**:
```yaml
# Guaranteed QoS
resources:
  limits:
    cpu: "1"
    memory: "1Gi"
  requests:
    cpu: "1"
    memory: "1Gi"
```

---

### **4. Practical Implications**
#### **CPU Management**
- **Bursting**: Set `limit > request` to allow temporary spikes (e.g., `request: 500m`, `limit: 1`).
- **No Bursting**: Set `limit == request` for consistent performance (Guaranteed QoS).

#### **Memory Management**
- **Avoid OOM Kills**: Ensure `limit` is sufficiently higher than the expected usage to accommodate temporary spikes (e.g., garbage collection in Java).
- **Overcommitment**: If many pods have `requests` much lower than `limits`, nodes can be overcommitted, risking OOM kills under load.

---

### **5. Common Pitfalls**
1. **Underestimating Memory Limits**:
   - Java/Python apps often require extra memory for runtime overhead (e.g., JVM heap).
   - Example: If an app uses `1Gi` heap, set `limit ≥ 1.5Gi` to account for non-heap memory.
2. **Ignoring CPU Throttling**:
   - Even with low CPU usage, aggressive throttling (from tight limits) can increase latency.
3. **Misconfigured QoS**:
   - Critical pods without `limits`/`requests` may be evicted unexpectedly (BestEffort QoS).

---

### **6. Best Practices**
1. **Start Conservatively**:
   - Set `requests` based on observed usage (e.g., using metrics from `kubectl top` or monitoring tools).
   - Set `limits` slightly higher than `requests` for breathing room.
2. **Monitor and Adjust**:
   - Use tools like Prometheus/Grafana to track usage and adjust `requests`/`limits` over time.
3. **Use Vertical Pod Autoscaling (VPA)**:
   - Automatically adjust resource configurations based on historical usage.

---

### **7. Example Breakdown**
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "250m"
  limits:
    memory: "128Mi"
    cpu: "500m"
```
- **Guaranteed**: 64Mi memory and 250m CPU.
- **Burst Capacity**: Up to 128Mi memory and 500m CPU.
- **Pod QoS**: Burstable (since `limits > requests`).

---

### **8. Key Takeaways**
- **CPU**:
  - Throttling is "safe" but degrades performance.
  - Use `limit ≥ request` to avoid unnecessary throttling.
- **Memory**:
  - Exceeding `limits` causes pod termination.
  - Always set `limit ≥ request` to prevent crashes.
- **QoS**:
  - Configure `limits` and `requests` to align with pod priority (e.g., `Guaranteed` for critical workloads).

By aligning `requests` and `limits` with application requirements and node capacity, you optimize performance, stability, and resource utilization in Kubernetes.
