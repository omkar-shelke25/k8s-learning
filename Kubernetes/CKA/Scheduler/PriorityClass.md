

📘 **Kubernetes PriorityClass – Comprehensive Deep Dive Notes**

---

### 🔹 1. Introduction to PriorityClass

**PriorityClass** is a Kubernetes API object in the `scheduling.k8s.io/v1` API group that assigns a numeric priority to Pods, influencing their scheduling and preemption behavior in a Kubernetes cluster. It allows cluster administrators to define the relative importance of workloads, ensuring critical Pods are prioritized over less critical ones during resource contention.

- **Purpose**: Prioritize Pod scheduling and manage resource allocation in oversubscribed clusters.
- **Scope**: Non-namespaced (cluster-wide), meaning a single PriorityClass can be referenced by Pods across all namespaces.
- **Core Mechanism**: The Kubernetes scheduler uses the priority value to determine the order of Pod scheduling and whether a Pod can preempt (evict) others to acquire resources.

---

### 🔹 2. Why PriorityClass Matters

In a Kubernetes cluster, resources like CPU, memory, and nodes are finite. When demand exceeds supply, the scheduler needs a mechanism to decide which Pods get resources first or which Pods should be evicted to make room for others. PriorityClass addresses this by:

1. **Ensuring Critical Workloads Run**: High-priority Pods (e.g., control plane components, business-critical services) are scheduled before lower-priority ones.
2. **Enabling Preemption**: High-priority Pods can evict lower-priority Pods when resources are scarce.
3. **Supporting Multi-Tenancy**: Allows different teams or workloads to be prioritized differently in shared clusters.
4. **Facilitating Resource Optimization**: Low-priority workloads (e.g., batch jobs) can run when resources are available but yield to critical workloads when needed.

**Real-World Example**:
- A payment processing service (high-priority) must always run, even if it means evicting a batch analytics job (low-priority).
- Cluster components like `kube-dns` or `kube-proxy` need top priority to ensure cluster stability.

---

### 🔹 3. Priority Ranges and Structure

Kubernetes assigns priorities as 32-bit integers, with specific ranges reserved for different purposes:

| **Range**                     | **Purpose**                                                                 | **Example Use Case**                       |
|-------------------------------|-----------------------------------------------------------------------------|--------------------------------------------|
| **-2,000,000,000 to 1,000,000,000** | Application and workload Pods (user-defined PriorityClasses)                | Business services, batch jobs              |
| **1,000,000,001 to 2,000,000,000** | System-critical Pods (e.g., `kube-system` components)                      | `kubelet`, `coredns`, `kube-proxy`         |

- **Key Insight**: Higher numeric values indicate higher priority. For example, a Pod with priority `1000000` will always be scheduled before one with priority `100`.
- **System Priorities**: Kubernetes reserves higher values (e.g., ~2B) for critical system components to ensure they are never preempted by user workloads.

---

### 🔹 4. Anatomy of a PriorityClass Object

A PriorityClass is defined using a YAML manifest. Here’s a detailed breakdown of its fields:

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
description: "Priority class for critical application workloads"
preemptionPolicy: PreemptLowerPriority
```

| **Field**              | **Description**                                                                                   | **Notes**                                                                 |
|-------------------------|--------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------|
| `metadata.name`         | Unique name of the PriorityClass.                                                                | Must be unique across the cluster.                                        |
| `value`                 | Integer defining the priority (higher = more important).                                         | Typically between -2B and 1B for user workloads.                           |
| `globalDefault`         | If `true`, this PriorityClass is assigned to Pods without a `priorityClassName`.                 | Only one PriorityClass can be `globalDefault: true`.                      |
| `description`           | Optional human-readable description for documentation.                                           | Useful for team collaboration and auditing.                               |
| `preemptionPolicy`      | Determines preemption behavior: `PreemptLowerPriority` (default) or `Never`.                     | `Never` prevents the Pod from evicting others, even if high-priority.     |

**Example**:
- A PriorityClass named `low-priority` with `value: 100` and `globalDefault: true` would assign priority `100` to any Pod that doesn’t explicitly specify a `priorityClassName`.

---

### 🔹 5. Assigning PriorityClass to Pods

To associate a Pod with a PriorityClass, include the `priorityClassName` field in the Pod’s `spec`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: critical-app
spec:
  priorityClassName: high-priority
  containers:
  - name: app
    image: nginx
```

- **Effect**: The Pod inherits the priority value of the `high-priority` PriorityClass (e.g., `1000000`).
- **Default Behavior**: If no `priorityClassName` is specified, the Pod gets:
  - Priority `0` (if no `globalDefault` PriorityClass exists).
  - The priority of the `globalDefault: true` PriorityClass (if defined).

---

### 🔹 6. Scheduling and Preemption Mechanics

The Kubernetes scheduler uses PriorityClass to make two key decisions:

#### 6.1. Scheduling Order
- When multiple Pods are pending, the scheduler prioritizes those with higher `value` fields.
- **Example**:
  - Pod A: `priorityClassName: high-priority` (value: `1000000`)
  - Pod B: `priorityClassName: low-priority` (value: `100`)
  - **Result**: Pod A is scheduled first, even if Pod B was created earlier.

#### 6.2. Preemption
- When a high-priority Pod cannot be scheduled due to resource constraints, the scheduler may evict lower-priority Pods to make room.
- **Preemption Workflow**:
  1. A high-priority Pod is pending and cannot be scheduled.
  2. The scheduler identifies nodes where the Pod could run if lower-priority Pods were removed.
  3. If the `preemptionPolicy` is `PreemptLowerPriority`, the scheduler evicts lower-priority Pods.
  4. The high-priority Pod is then scheduled on the freed node.
- **Conditions for Preemption**:
  - The high-priority Pod must have a higher `value` than the Pods it would evict.
  - Preemption respects Pod Disruption Budgets (PDBs) to avoid violating availability constraints.
- **PreemptionPolicy: Never**:
  - Pods with this policy will not evict others, even if they have a higher priority. They wait in the queue instead.

**Real-World Scenario**:
- A cluster runs out of CPU resources. A Pod with `high-priority` (value: `1000000`) is pending. The scheduler evicts a Pod with `low-priority` (value: `100`) to free resources, ensuring the critical Pod runs.

---

### 🔹 7. Global Default PriorityClass

- **Purpose**: Provides a fallback priority for Pods that don’t specify a `priorityClassName`.
- **Default Behavior**:
  - If no `globalDefault: true` PriorityClass exists, Pods without a `priorityClassName` get priority `0`.
  - If a `globalDefault: true` PriorityClass exists, its `value` is used.
- **Restriction**: Only one PriorityClass in the cluster can have `globalDefault: true`. Attempting to create another will result in an error.
- **Example**:
  ```yaml
  apiVersion: scheduling.k8s.io/v1
  kind: PriorityClass
  metadata:
    name: default-priority
  value: 1000
  globalDefault: true
  description: "Default priority for all Pods"
  ```
  - All Pods without a `priorityClassName` will inherit priority `1000`.

**Best Practice**: Use `globalDefault` sparingly to avoid unintended prioritization of non-critical workloads.

---

### 🔹 8. System Priority Classes

Kubernetes includes built-in PriorityClasses for critical system components:

| **PriorityClass**            | **Approximate Value** | **Purpose**                              |
|------------------------------|-----------------------|------------------------------------------|
| `system-node-critical`       | ~2,000,000,000        | Pods critical to node operation (e.g., `kubelet`) |
| `system-cluster-critical`     | ~2,000,000,000        | Cluster-wide critical Pods (e.g., `coredns`) |

- **Why Reserved?** These ensure system components are never preempted by user workloads, maintaining cluster stability.
- **Warning**: Avoid creating custom PriorityClasses with values close to or exceeding 2B, as this could interfere with system Pods.

---

### 🔹 9. Viewing and Managing PriorityClasses

To inspect PriorityClasses in your cluster:

```bash
kubectl get priorityclass
```

**Sample Output**:
```
NAME                      VALUE        GLOBAL-DEFAULT   AGE
system-cluster-critical   2000001000   false            10d
system-node-critical      2000000000   false            10d
high-priority             1000000      false            2h
low-priority              100          false            2h
```

To inspect a specific PriorityClass:
```bash
kubectl describe priorityclass high-priority
```

To delete a PriorityClass:
```bash
kubectl delete priorityclass high-priority
```

**Note**: Deleting a PriorityClass does not affect running Pods but will prevent new Pods from referencing it.

---

### 🔹 10. Controlling PriorityClass Usage in Multi-Tenant Clusters

Since PriorityClasses are non-namespaced, any Pod in any namespace can reference them. This can lead to misuse (e.g., a developer assigning `high-priority` to a non-critical workload). To mitigate this, use policy enforcement tools:

#### 10.1. RBAC (Role-Based Access Control)
- Restrict who can create or modify PriorityClasses using RBAC.
- Example RBAC Role:
  ```yaml
  apiVersion: rbac.authorization.k8s.io/v1
  kind: ClusterRole
  metadata:
    name: priorityclass-admin
  rules:
  - apiGroups: ["scheduling.k8s.io"]
    resources: ["priorityclasses"]
    verbs: ["create", "update", "delete"]
  ```
  - Bind this role only to trusted users or service accounts.

#### 10.2. Policy Engines (Kyverno or OPA Gatekeeper)
- Use Kyverno or OPA to enforce namespace-specific restrictions on PriorityClass usage.
- **Kyverno Example**: Prevent the `high-priority` PriorityClass in the `dev` namespace:
  ```yaml
  apiVersion: kyverno.io/v1
  kind: ClusterPolicy
  metadata:
    name: restrict-high-priority
  spec:
    rules:
    - name: block-high-priority-in-dev
      match:
        any:
        - resources:
            kinds: ["Pod"]
            namespaces: ["dev"]
      validate:
        message: "The high-priority PriorityClass is not allowed in the dev namespace"
        pattern:
          spec:
            priorityClassName: "!high-priority"
  ```

- **OPA Gatekeeper Example**:
  ```yaml
  apiVersion: constraints.gatekeeper.sh/v1beta1
  kind: K8sDenyPriorityClass
  metadata:
    name: deny-high-priority-in-dev
  spec:
    match:
      kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
      namespaces: ["dev"]
    parameters:
      restrictedPriorityClasses: ["high-priority"]
  ```

This ensures only approved namespaces can use high-priority classes, improving cluster governance.

---

### 🔹 11. Best Practices for PriorityClass in Production

1. **Define Clear Priority Tiers**:
   - Create distinct tiers (e.g., `high-priority: 1000000`, `medium-priority: 10000`, `low-priority: 100`) to simplify scheduling logic.
   - Avoid overly granular priorities (e.g., `1001`, `1002`) to prevent confusion.

2. **Restrict High-Priority Classes**:
   - Use RBAC and policy engines to limit who can assign high-priority classes.
   - Reserve high values (e.g., >500000) for critical workloads only.

3. **Minimize Preemption**:
   - Overuse of preemption can lead to Pod churn or instability.
   - Set `preemptionPolicy: Never` for Pods that don’t need to evict others.

4. **Monitor and Audit**:
   - Regularly review `kubectl get priorityclass` to ensure no unauthorized classes exist.
   - Use monitoring tools to track preemption events (e.g., via Kubernetes events or logs).

5. **Integrate with Pod Disruption Budgets (PDBs)**:
   - Use PDBs to prevent excessive preemption from disrupting critical applications.
   - Example:
     ```yaml
     apiVersion: policy/v1
     kind: PodDisruptionBudget
     metadata:
       name: critical-app-pdb
     spec:
       minAvailable: 2
       selector:
         matchLabels:
           app: critical-app
     ```

6. **Test Preemption Behavior**:
   - Simulate resource contention in a staging environment to validate PriorityClass behavior.

---

### 🔹 12. Common Mistakes and Pitfalls

1. **Overusing High Priorities**:
   - Assigning high priorities to non-critical workloads can starve other Pods or cause unnecessary preemption.
   - **Fix**: Restrict high-priority classes via policies.

2. **Multiple globalDefault PriorityClasses**:
   - Attempting to set `globalDefault: true` on multiple PriorityClasses causes conflicts.
   - **Fix**: Ensure only one PriorityClass has `globalDefault: true`.

3. **Ignoring System Priorities**:
   - Creating custom PriorityClasses with values close to `system-node-critical` or `system-cluster-critical` can disrupt cluster stability.
   - **Fix**: Stay within the -2B to 1B range for user workloads.

4. **Uncontrolled Preemption**:
   - Aggressive preemption can lead to cascading evictions.
   - **Fix**: Use `preemptionPolicy: Never` or PDBs where appropriate.

5. **Lack of Namespace Governance**:
   - Allowing all namespaces to use high-priority classes can lead to resource abuse.
   - **Fix**: Implement Kyverno or OPA policies.

---

### 🔹 13. Advanced Considerations

1. **Interaction with Resource Quotas**:
   - PriorityClass does not directly interact with ResourceQuotas, but high-priority Pods may still be constrained by namespace quotas.
   - Ensure quotas align with priority expectations (e.g., reserve more resources for namespaces with high-priority workloads).

2. **Cluster Autoscaling**:
   - In clusters with autoscalers, high-priority Pods may trigger node scaling if they cannot be scheduled.
   - Ensure autoscaler policies account for PriorityClass to avoid overprovisioning.

3. **Custom Schedulers**:
   - If using a custom scheduler, ensure it respects PriorityClass values and preemption policies.
   - Default Kubernetes scheduler (`kube-scheduler`) handles this automatically.

4. **Multi-Cluster Scenarios**:
   - In multi-cluster setups, synchronize PriorityClass definitions across clusters to ensure consistent behavior.

5. **Observability**:
   - Use tools like Prometheus and Grafana to monitor preemption events and Pod scheduling delays.
   - Example metric: `scheduler_preemption_victims` (tracks preempted Pods).

---

### 🔹 14. Hands-On Lab: Exploring PriorityClass

Here’s a step-by-step lab to solidify your understanding of PriorityClass in a Kubernetes cluster (assumes a cluster like Minikube or Kind).

#### Step 1: Set Up PriorityClasses
Create three PriorityClasses: `high-priority`, `medium-priority`, and `low-priority`.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
description: "For critical workloads"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: medium-priority
value: 10000
globalDefault: false
description: "For standard workloads"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: low-priority
value: 100
globalDefault: true
description: "For non-critical workloads"
EOF
```

#### Step 2: Create Pods with Different Priorities
Deploy three Pods with different PriorityClasses.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: high-priority-pod
spec:
  priorityClassName: high-priority
  containers:
  - name: nginx
    image: nginx
    resources:
      requests:
        cpu: "500m"
      limits:
        cpu: "500m"
---
apiVersion: v1
kind: Pod
metadata:
  name: medium-priority-pod
spec:
  priorityClassName: medium-priority
  containers:
  - name: nginx
    image: nginx
    resources:
      requests:
        cpu: "500m"
      limits:
        cpu: "500m"
---
apiVersion: v1
kind: Pod
metadata:
  name: low-priority-pod
spec:
  priorityClassName: low-priority
  containers:
  - name: nginx
    image: nginx
    resources:
      requests:
        cpu: "500m"
      limits:
        cpu: "500m"
EOF
```

#### Step 3: Simulate Resource Contention
- Reduce available CPU in your cluster (e.g., by scaling down nodes or setting resource limits).
- Deploy a new high-priority Pod that cannot be scheduled due to resource constraints:
  ```bash
  cat <<EOF | kubectl apply -f -
  apiVersion: v1
  kind: Pod
  metadata:
    name: high-priority-pod-2
  spec:
    priorityClassName: high-priority
    containers:
    - name: nginx
      image: nginx
      resources:
        requests:
          cpu: "1000m"
        limits:
          cpu: "1000m"
  EOF
  ```

- **Expected Result**: The `low-priority-pod` or `medium-priority-pod` is preempted to make room for `high-priority-pod-2`.

#### Step 4: Observe Preemption
Check events to confirm preemption:
```bash
kubectl get events
```

#### Step 5: Enforce Namespace Restrictions
Create a Kyverno policy to block `high-priority` in the `dev` namespace:
```bash
kubectl create namespace dev
cat <<EOF | kubectl apply -f -
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-high-priority
spec:
  rules:
  - name: block-high-priority-in-dev
    match:
      any:
      - resources:
          kinds: ["Pod"]
          namespaces: ["dev"]
    validate:
      message: "The high-priority PriorityClass is not allowed in the dev namespace"
      pattern:
        spec:
          priorityClassName: "!high-priority"
EOF
```

- Test by deploying a Pod in the `dev` namespace with `priorityClassName: high-priority`. It should be rejected.

#### Step 6: Clean Up
```bash
kubectl delete pod high-priority-pod medium-priority-pod low-priority-pod high-priority-pod-2
kubectl delete priorityclass high-priority medium-priority low-priority
kubectl delete clusterpolicy restrict-high-priority
kubectl delete namespace dev
```

---

### 🔹 15. Recap of Key Concepts

- **PriorityClass**: Assigns numeric priorities to Pods for scheduling and preemption.
- **Non-Namespaced**: Applies cluster-wide, requiring governance in multi-tenant clusters.
- **Priority Ranges**: -2B to 1B for user workloads; >1B for system Pods.
- **Preemption**: High-priority Pods can evict lower-priority ones unless `preemptionPolicy: Never`.
- **Global Default**: One PriorityClass can set the default priority for unspecified Pods.
- **Governance**: Use RBAC, Kyverno, or OPA to control PriorityClass usage.
- **Best Practices**: Clear tiers, restricted high priorities, minimal preemption, and monitoring.

