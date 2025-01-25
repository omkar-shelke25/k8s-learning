### Kubernetes QoS Classes: Examples and Purposes

Kubernetes uses **Quality of Service (QoS)** classes to prioritize resource allocation and eviction decisions for Pods during resource contention. These classes ensure critical workloads receive higher priority while optimizing cluster resource utilization. Below is a detailed explanation of the three QoS classes, examples, and their purposes.

---

### **1. QoS Classes and Examples**
#### **a. Guaranteed**  
- **Criteria**:  
  - All containers in the Pod must specify **equal** `requests` and `limits` for both CPU and memory.  
  - If a container defines a `limit` but omits the `request`, Kubernetes automatically sets `request = limit` .  
- **Example**:  
  ```yaml
  spec:
    containers:
      - name: nginx
        image: nginx
        resources:
          limits:
            cpu: "700m"
            memory: "200Mi"
          requests:
            cpu: "700m"
            memory: "200Mi"
  ```  
  This Pod will be classified as `Guaranteed` because both CPU and memory `requests` and `limits` are equal .

---

#### **b. Burstable**  
- **Criteria**:  
  - The Pod does not meet the `Guaranteed` criteria.  
  - At least one container has a CPU or memory `request` or `limit` (even if only one resource is defined) .  
- **Example**:  
  ```yaml
  spec:
    containers:
      - name: nginx
        image: nginx
        resources:
          limits:
            memory: "200Mi"
          requests:
            memory: "100Mi"
  ```  
  Here, memory `request` and `limit` differ, and no CPU is specified. This Pod will be `Burstable` .  
  Another example is a Pod with one container defining a resource and another with none .

---

#### **c. BestEffort**  
- **Criteria**:  
  - No container in the Pod specifies **any** CPU or memory `requests` or `limits` .  
- **Example**:  
  ```yaml
  spec:
    containers:
      - name: nginx
        image: nginx
  ```  
  Since no resources are defined, this Pod is classified as `BestEffort` .

---

### **2. Purposes of QoS Classes**  
#### **a. Eviction Priority During Resource Contention**  
- When a node faces resource pressure (e.g., memory or CPU exhaustion), Kubernetes evicts Pods in this order:  
  **BestEffort → Burstable → Guaranteed** .  
- Only Pods exceeding their `requests` are eligible for eviction. For example, a `Burstable` Pod using more memory than its `request` may be evicted after all `BestEffort` Pods .

#### **b. Resource Allocation and Overcommitment**  
- **Guaranteed**: Reserved resources ensure stability. These Pods can use **exclusive CPU cores** if configured with integer CPU values .  
- **Burstable**: Can "burst" beyond `requests` if resources are available but are constrained by `limits` .  
- **BestEffort**: Use leftover resources but are first to be terminated during shortages .

#### **c. OOM (Out-Of-Memory) Handling**  
- Kubernetes adjusts the **OOM score** of processes based on QoS:  
  - `BestEffort`: Highest score (1000), making them prime targets for OOM kills .  
  - `Guaranteed`: Lowest score (-998), protecting them from early termination .  
  - `Burstable`: Scores depend on memory usage relative to `requests` (e.g., exceeding `requests` raises the score) .

#### **d. Cgroup Configuration**  
- Kubernetes uses cgroups to enforce resource limits:  
  - `Guaranteed` Pods are placed directly under the root cgroup (`kubepods`).  
  - `Burstable` and `BestEffort` Pods are grouped under sub-cgroups (`kubepods/burstable` or `kubepods/besteffort`) .

---

### **3. Practical Use Cases**  
- **Mission-Critical Workloads**: Use `Guaranteed` for databases or stateful services requiring stable resources .  
- **Batch Jobs**: `Burstable` allows flexible resource usage without strict guarantees.  
- **Testing/Dev Environments**: `BestEffort` suits non-critical workloads where interruptions are acceptable .

### **Summary Table**  
| QoS Class    | Eviction Priority | Resource Guarantee        | Use Case                  |  
|--------------|-------------------|---------------------------|---------------------------|  
| Guaranteed   | Lowest            | Strict (requests = limits)| Critical applications     |  
| Burstable    | Medium            | Partial (requests ≤ limits)| Flexible workloads      |  
| BestEffort   | Highest           | None                      | Non-critical tasks        |  

For further details, refer to the Kubernetes documentation and community guides .
