
# Deep Notes on Node Selectors and Node Affinity in Kubernetes

## 1. Introduction to Pod Scheduling in Kubernetes
Kubernetes is a container orchestration platform that automates the deployment, scaling, and management of containerized applications. Pods, the smallest deployable units, are scheduled onto nodes (worker machines) by the **Kubernetes scheduler**. The scheduler uses a combination of resource availability, constraints, and policies to determine the optimal node for each pod.

### 1.1 The Scheduling Problem
In a Kubernetes cluster, nodes may have diverse characteristics, such as:
- **Hardware Differences**: Varying CPU, memory, or specialized hardware (e.g., GPUs, TPUs).
- **Geographical Location**: Nodes in different regions (e.g., `us-east`, `eu-west`).
- **Roles**: Dedicated nodes for specific workloads (e.g., database, compute-intensive).
- **Default Behavior**: The scheduler places pods on any node with sufficient resources (CPU, memory, etc.), which can lead to:
  - Resource-intensive pods on underpowered nodes, causing performance degradation or crashes.
  - Pods running on nodes without required hardware (e.g., GPU workloads on non-GPU nodes).
  - Inefficient resource utilization in multi-region clusters.

**Example Scenario**:
- **Cluster Setup**:
  - `node1`: High-resource (16 CPU cores, 64GB RAM, GPU).
  - `node2`, `node3`: Low-resource (4 CPU cores, 16GB RAM, no GPU).
- **Workload**: Machine learning pods requiring GPUs and high memory.
- **Problem**: Default scheduler may place these pods on `node2` or `node3`, leading to failures or poor performance.
- **Desired Outcome**: Restrict pods to `node1` to ensure compatibility and performance.

### 1.2 Solution: Controlling Pod Placement
Kubernetes provides two primary mechanisms to control pod placement:
- **Node Selectors**: Simple, exact-match rules to assign pods to nodes with specific labels.
- **Node Affinity**: Advanced rules supporting complex logic, preferences, and constraints.
Both rely on **labels** (key-value pairs) applied to nodes and matching rules defined in pod specifications.

### 1.3 Role of Labels
- Labels are arbitrary key-value pairs attached to Kubernetes objects (e.g., nodes, pods).
- Used to identify node characteristics (e.g., `size=large`, `hardware=gpu`, `region=us-east`).
- **Command to Label Nodes**:
  ```bash
  kubectl label nodes <node-name> <key>=<value>
  ```
  **Example**:
  ```bash
  kubectl label nodes node1 size=large
  ```
- **Verify Labels**:
  ```bash
  kubectl get nodes --show-labels
  ```
  **Sample Output**:
  ```
  NAME    STATUS   ROLES    LABELS
  node1   Ready    worker   size=large,beta.kubernetes.io/os=linux
  node2   Ready    worker   beta.kubernetes.io/os=linux
  node3   Ready    worker   beta.kubernetes.io/os=linux
  ```

---

## 2. Node Selectors: Simple Scheduling Mechanism

### 2.1 Definition
- **Node Selector**: A Kubernetes feature that restricts pod scheduling to nodes with specific labels using a single key-value pair in the pod’s `spec.nodeSelector` field.
- **Purpose**: Ensure pods run on nodes with specific attributes (e.g., high resources, specific hardware).

### 2.2 Mechanics
Node selectors operate by matching the pod’s `nodeSelector` field to node labels. The process involves:
1. **Labeling Nodes**:
   - Assign labels to nodes to describe their properties.
   - **Example**:
     ```bash
     kubectl label nodes node1 size=large
     kubectl label nodes node1 hardware=gpu
     ```
   - Labels can describe hardware, location, or role (e.g., `size=large`, `region=us-east`).
2. **Defining Node Selector in Pod**:
   - Add a `nodeSelector` field under `spec` in the pod’s YAML.
   - **Example YAML**:
     ```yaml
     apiVersion: v1
     kind: Pod
     metadata:
       name: ml-pod
     spec:
       containers:
       - name: ml-container
         image: ml-image:latest
       nodeSelector:
         size: large
     ```
   - This pod schedules only on nodes with `size=large` (e.g., `node1`).
3. **Scheduler Behavior**:
   - The scheduler:
     1. Filters nodes to those with the exact label match (e.g., `size=large`).
     2. Selects a node from the filtered list based on resource availability, pod constraints, and other factors (e.g., taints, tolerations).
   - **If Matching Node Exists**: Pod is scheduled (e.g., on `node1`).
   - **If No Matching Node**: Pod remains **Pending** with an event:
     ```bash
     kubectl describe pod ml-pod
     ```
     **Sample Output**:
     ```
     Events:
       Type     Reason            Age   From               Message
       ----     ------            ----  ----               -------
       Warning  FailedScheduling  0s    default-scheduler  0/3 nodes are available: 3 node(s) didn't match node selector.
     ```

### 2.3 Use Case
- **Scenario**: Schedule a machine learning pod requiring high resources on `node1` (labeled `size=large`).
- **Steps**:
  1. Label `node1`:
     ```bash
     kubectl label nodes node1 size=large
     ```
  2. Create pod YAML (as above).
  3. Apply:
     ```bash
     kubectl apply -f ml-pod.yaml
     ```
  4. Verify placement:
     ```bash
     kubectl get pods -o wide
     ```
     **Output**:
     ```
     NAME     READY   STATUS    NODE
     ml-pod   1/1     Running   node1
     ```

### 2.4 Advantages
- **Simplicity**: Requires only a single key-value pair, easy to configure and understand.
- **Predictability**: Strict matching ensures pods run only on intended nodes.
- **Low Overhead**: Minimal impact on scheduler performance, suitable for small to medium clusters.
- **Ease of Use**: Ideal for straightforward requirements (e.g., GPU workloads on GPU nodes).

### 2.5 Limitations
- **Exact Match Only**: Requires precise key-value matches, with no support for:
  - Logical operators (`OR`, `AND`, `NOT`).
  - Multiple values for a single key (e.g., `size=large` OR `size=medium`).
  - Negation (e.g., avoid `size=small`).
- **Static Behavior**: Once scheduled, label changes on nodes (e.g., removing `size=large`) do not affect running pods.
- **No Complex Logic**: Multiple labels in `nodeSelector` imply a logical AND.
  - **Example**:
    ```yaml
    nodeSelector:
      size: large
      region: us-east
    ```
    - Requires a node with **both** `size=large` AND `region=us-east`.
- **Scalability**: Less flexible for large, dynamic clusters with diverse node types.

### 2.6 Edge Cases
- **No Matching Nodes**:
  - If no node has the specified label, the pod remains **Pending**.
  - **Mitigation**: Verify labels:
    ```bash
    kubectl get nodes --show-labels
    ```
- **Multiple Labels**:
  - All `nodeSelector` key-value pairs must match (logical AND).
  - **Example**:
    ```yaml
    nodeSelector:
      size: large
      hardware: gpu
    ```
    - Fails if no node has both labels.
- **Label Overwrites**:
  - Overwriting a label:
    ```bash
    kubectl label nodes node1 size=medium --overwrite
    ```
    - Kubernetes uses the latest value; older pods remain unaffected.
- **Conflicts with Other Constraints**:
  - Taints, tolerations, resource limits, or pod anti-affinity may prevent scheduling even if labels match.
  - **Example**: A node with `size=large` but a taint `key=value:NoSchedule` will reject pods without a matching toleration.
- **Dynamic Clusters**:
  - Adding or removing nodes may change available labels, affecting new pod scheduling.

### 2.7 Practical Example
- **Scenario**: Deploy a GPU-based pod on `node1` (labeled `hardware=gpu`).
- **Steps**:
  1. Label node:
     ```bash
     kubectl label nodes node1 hardware=gpu
     ```
  2. Create `gpu-pod.yaml`:
     ```yaml
     apiVersion: v1
     kind: Pod
     metadata:
       name: gpu-pod
     spec:
       containers:
       - name: gpu-container
         image: tensorflow/tensorflow:latest-gpu
       nodeSelector:
         hardware: gpu
     ```
  3. Apply and verify:
     ```bash
     kubectl apply -f gpu-pod.yaml
     kubectl get pods -o wide
     ```
     **Output**:
     ```
     NAME      READY   STATUS    NODE
     gpu-pod   1/1     Running   node1
     ```
  4. Test failure:
     - Remove label: `kubectl label nodes node1 hardware-`
     - Create new pod: It remains **Pending** due to no matching nodes.

### 2.8 Debugging Node Selectors
- **Pod Pending**:
  - Check node labels: `kubectl get nodes --show-labels`.
  - Check pod events: `kubectl describe pod <pod-name>`.
- **Unexpected Placement**:
  - Verify `nodeSelector` syntax in YAML.
  - Check for conflicting constraints (e.g., taints, resource limits).
- **Label Mismatches**:
  - Ensure labels are applied correctly and consistently across nodes.

---

## 3. Node Affinity: Advanced Scheduling Mechanism

### 3.1 Definition
- **Node Affinity**: A powerful Kubernetes feature that extends node selectors with complex rules, logical operators, and scheduling preferences.
- **Purpose**: Enable fine-grained control over pod placement, supporting scenarios like preferring certain nodes, avoiding others, or combining multiple conditions.

### 3.2 Mechanics
Node affinity is defined under `spec.affinity.nodeAffinity` in the pod’s YAML and supports two phases: **scheduling** (pod placement) and **execution** (post-placement behavior).

1. **Node Affinity Types**:
   - **requiredDuringSchedulingIgnoredDuringExecution**:
     - **Scheduling**: Pod **must** schedule on a node matching the affinity rules; otherwise, it remains **Pending**.
     - **Execution**: Label changes after scheduling (e.g., removing `size=large`) do not affect running pods.
     - **Use Case**: Critical workloads requiring specific nodes (e.g., GPU pods).
   - **preferredDuringSchedulingIgnoredDuringExecution**:
     - **Scheduling**: Scheduler prefers nodes matching the rules but schedules on any node if no match is found.
     - **Execution**: Label changes do not affect running pods.
     - **Use Case**: Non-critical workloads with node preferences (e.g., prefer high-resource nodes).
   - **Future Types** (not available as of July 2025):
     - **requiredDuringSchedulingRequiredDuringExecution**: Evicts pods if node labels no longer match during execution.
     - **preferredDuringSchedulingRequiredDuringExecution**: Prefers nodes during scheduling but enforces rules during execution.
     - **Note**: These are planned features for dynamic environments (e.g., auto-scaling clusters).

2. **Node Selector Terms**:
   - Defined under `nodeSelectorTerms`, an array of conditions.
   - Each term contains `matchExpressions` with:
     - **Key**: Label key (e.g., `size`).
     - **Operator**: Matching logic (`In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt`, `Lt`).
     - **Values**: List of values (used with `In`, `NotIn`, `Gt`, `Lt`).
   - **Logical Evaluation**:
     - **Within a Term**: All `matchExpressions` must be true (logical AND).
     - **Across Terms**: At least one term must be satisfied (logical OR).

3. **Operators**:
   - **In**: Matches if the node’s label value is in the list.
     - Example: `size In (large, medium)` matches `size=large` or `size=medium`.
   - **NotIn**: Matches if the node’s label value is not in the list.
     - Example: `size NotIn (small)` matches any node where `size` is not `small`.
   - **Exists**: Matches if the node has the label key (value ignored).
     - Example: `size Exists` matches any node with a `size` label.
   - **DoesNotExist**: Matches if the node lacks the label key.
     - Example: `size DoesNotExist` matches nodes without a `size` label.
   - **Gt**, **Lt**: Numerical comparisons for label values.
     - Example: `cpu-count Gt 8` matches nodes with `cpu-count` > 8.
   - **Validation**: `Exists` and `DoesNotExist` do not use `values`; including them causes errors.

4. **Example YAML (Required Affinity)**:
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: affinity-pod
   spec:
     containers:
     - name: app
       image: nginx
     affinity:
       nodeAffinity:
         requiredDuringSchedulingIgnoredDuringExecution:
           nodeSelectorTerms:
           - matchExpressions:
             - key: size
               operator: In
               values:
               - large
               - medium
             - key: region
               operator: In
               values:
               - us-east
   ```
   - Matches nodes with `size=large` OR `size=medium` AND `region=us-east`.

5. **Example YAML (Preferred Affinity)**:
   ```yaml
   affinity:
     nodeAffinity:
       preferredDuringSchedulingIgnoredDuringExecution:
       - weight: 80
         preference:
           matchExpressions:
           - key: size
             operator: In
             values:
             - large
       - weight: 20
         preference:
           matchExpressions:
           - key: size
             operator: In
             values:
             - medium
   ```
   - Prioritizes `size=large` (weight 80) over `size=medium` (weight 20); schedules on any node if no match.

6. **Scheduler Behavior**:
   - **Required Affinity**:
     - Filters nodes to those matching the rules.
     - Pod remains **Pending** if no match is found.
     - **Event**:
       ```bash
       kubectl describe pod affinity-pod
       ```
       **Output**:
       ```
     Events:
       Type     Reason            Age   From               Message
       ----     ------            ----  ----               -------
       Warning  FailedScheduling  0s    default-scheduler  0/3 nodes are available: 3 node(s) didn't match node affinity.
       ```
   - **Preferred Affinity**:
     - Assigns scores to nodes based on weights (1–100).
     - Matching nodes get higher scores; non-matching nodes are still considered.
   - **Execution**: With `IgnoredDuringExecution`, label changes do not affect running pods.

### 3.3 Use Case
- **Cluster Setup**:
  - `node1`: `size=large, region=us-east`
  - `node2`: `size=medium, region=us-east`
  - `node3`: `region=us-west` (no `size` label)
- **Goal**: Schedule a pod on `size=large` or `size=medium` nodes in `us-east`.
- **YAML** (as above for required affinity).
- **Outcome**:
  - Schedules on `node1` or `node2`.
  - `node3` is excluded (wrong region).
- **Alternative (Avoid Small Nodes)**:
  ```yaml
  - matchExpressions:
    - key: size
      operator: NotIn
      values:
      - small
  ```
  - Matches `node1`, `node2`, and potentially `node3` unless combined with `region=us-east`.

### 3.4 Advanced Example
- **Goal**: Schedule on nodes with (`size=large` AND `region=us-east`) OR (`size=medium` AND `region=us-west`).
- **YAML**:
  ```yaml
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: size
            operator: In
            values: [large]
          - key: region
            operator: In
            values: [us-east]
        - matchExpressions:
          - key: size
            operator: In
            values: [medium]
          - key: region
            operator: In
            values: [us-west]
  ```
- **Outcome**:
  - Matches nodes satisfying either term (logical OR).
  - Example: Schedules on `node1` (`size=large`, `region=us-east`) or a node with `size=medium`, `region=us-west`.

### 3.5 Advantages
- **Flexible Rules**: Supports `In`, `NotIn`, `Exists`, `Gt`, etc., for complex logic.
- **Granular Control**: Combine multiple conditions (e.g., `size` AND `region` OR `hardware`).
- **Scheduling Options**: `required` for strict placement, `preferred` for fallbacks.
- **Scalable**: Suitable for large, dynamic clusters with diverse node types.
- **Future-Proof**: Planned `RequiredDuringExecution` types will handle dynamic label changes.

### 3.6 Limitations
- **Complexity**: Requires understanding operators, terms, and lifecycle phases.
- **Configuration Errors**:
  - Example: Using `values` with `Exists`:
    ```yaml
    - key: size
      operator: Exists
      values: [large] # Invalid
    ```
  - Causes validation errors.
- **Execution Limitation**: `IgnoredDuringExecution` does not handle dynamic label changes.
- **Performance Overhead**: Complex rules may increase scheduler latency in large clusters.
- **Learning Curve**: Steeper than node selectors for new users.

### 3.7 Edge Cases
- **No Matching Nodes**:
  - **Required**: Pod remains **Pending**.
  - **Preferred**: Pod schedules on any available node.
- **Label Changes During Execution**:
  - With `IgnoredDuringExecution`, running pods are unaffected.
  - Future `RequiredDuringExecution` types would evict pods.
- **Multiple Terms**:
  - Logical OR across terms; logical AND within a term.
  - Example: A pod requiring `size=large` AND `region=us-east` OR `size=medium` AND `region=us-west` needs two terms.
- **Invalid Configurations**:
  - Validate YAML with:
    ```bash
    kubectl apply --dry-run=client -f pod.yaml
    ```
- **Weight Conflicts in Preferred Affinity**:
  - Weights (1–100) determine priority; ensure weights reflect desired preferences.

### 3.8 Practical Example
- **Scenario**: Deploy a web application preferring `size=large` nodes in `us-east`, but allowing `size=medium` as a fallback.
- **Steps**:
  1. Label nodes:
     ```bash
     kubectl label nodes node1 size=large region=us-east
     kubectl label nodes node2 size=medium region=us-east
     ```
  2. Create `web-pod.yaml`:
     ```yaml
     apiVersion: v1
     kind: Pod
     metadata:
       name: web-pod
     spec:
       containers:
       - name: web-container
         image: nginx
       affinity:
         nodeAffinity:
           preferredDuringSchedulingIgnoredDuringExecution:
           - weight: 80
             preference:
               matchExpressions:
               - key: size
                 operator: In
                 values:
                 - large
               - key: region
                 operator: In
                 values:
                 - us-east
           - weight: 20
             preference:
               matchExpressions:
               - key: size
                 operator: In
                 values:
                 - medium
               - key: region
                 operator: In
                 values:
                 - us-east
     ```
  3. Apply and verify:
     ```bash
     kubectl apply -f web-pod.yaml
     kubectl get pods -o wide
     ```
     **Output** (assuming `node1` has more resources):
     ```
     NAME      READY   STATUS    NODE
     web-pod   1/1     Running   node1
     ```
  4. Test fallback:
     - Remove `size=large` label: `kubectl label nodes node1 size-`
     - Reapply: Pod schedules on `node2` (`size=medium`).

### 3.9 Debugging Node Affinity
- **Pod Pending**:
  - Check affinity rules: Verify YAML syntax and logic.
  - Check node labels: `kubectl get nodes --show-labels`.
  - Check events: `kubectl describe pod`.
- **Unexpected Placement**:
  - Verify weights in `preferred` rules.
  - Check for conflicts with taints, tolerations, or resource limits.
- **Validation Errors**:
  - Test YAML: `kubectl apply --dry-run=client`.

---

## 4. Comparison: Node Selectors vs. Node Affinity
| **Aspect**                     | **Node Selectors**                              | **Node Affinity**                              |
|-------------------------------|------------------------------------------------|-----------------------------------------------|
| **Syntax**                    | `nodeSelector: key: value`                    | `affinity.nodeAffinity` with terms/operators   |
| **Matching Logic**            | Exact key-value match                         | `In`, `NotIn`, `Exists`, `Gt`, `Lt`, etc.     |
| **Flexibility**               | Limited (single condition, AND only)          | Complex (OR, AND, NOT, multiple conditions)   |
| **Scheduling Behavior**       | Strict (Pending if no match)                  | Strict (`required`) or lenient (`preferred`)   |
| **Execution Behavior**        | Ignored                                       | Ignored (future: `RequiredDuringExecution`)   |
| **Use Case**                  | Simple placement (e.g., GPU nodes)            | Complex rules (e.g., prefer regions, avoid nodes) |
| **Complexity**                | Easy to configure                            | Requires careful configuration                |
| **Performance**               | Minimal scheduler overhead                    | Higher overhead for complex rules             |
| **Scalability**               | Limited for dynamic clusters                  | Suitable for large, diverse clusters           |

---

## 5. Integration with Other Kubernetes Features
- **Taints and Tolerations**:
  - Node selectors/affinity filter nodes to include; taints exclude nodes unless pods have matching tolerations.
  - **Example**:
    - Node with taint: `kubectl taint nodes node1 key=value:NoSchedule`.
    - Pod must include:
      ```yaml
      tolerations:
      - key: "key"
        operator: "Equal"
        value: "value"
        effect: "NoSchedule"
      ```
- **Pod Affinity/Anti-Affinity**:
  - Node affinity targets nodes; pod affinity/anti-affinity controls pod co-location or separation.
  - Example: Schedule a pod on nodes where another pod (e.g., database) is running.
- **Resource Requests/Limits**:
  - Node selectors/affinity ensure node compatibility; resource requests/limits ensure sufficient CPU/memory.
  - Example:
    ```yaml
    resources:
      requests:
        cpu: "2"
        memory: "4Gi"
    ```
- **Topology Spread Constraints**:
  - Combine with node affinity to distribute pods across zones or regions.
  - Example: Spread pods across `region=us-east` and `region=us-west`.

---

## 6. Practical Applications
- **Node Selectors**:
  - Deploy GPU workloads to GPU nodes (`hardware=gpu`).
  - Run database pods on high-memory nodes (`size=large`).
  - Restrict pods to a specific region (`region=us-east`).
- **Node Affinity**:
  - Prefer high-resource nodes (`size=large`) but allow fallbacks (`size=medium`).
  - Avoid low-resource nodes (`size NotIn (small)`).
  - Schedule pods across multiple regions with preferences (`region In (us-east, us-west)`).
  - Combine hardware and location requirements (`size=large` AND `region=us-east`).

---

## 7. Best Practices
1. **Consistent Labeling**:
   - Use meaningful, standardized labels (e.g., `size=large`, `hardware=gpu`).
   - Document label conventions for the cluster.
2. **Validate Configurations**:
   - Test YAML: `kubectl apply --dry-run=client`.
   - Verify node labels: `kubectl get nodes --show-labels`.
3. **Use Node Selectors for Simplicity**:
   - Ideal for single, strict requirements (e.g., GPU pods).
4. **Use Node Affinity for Flexibility**:
   - Leverage `preferred` rules for non-critical workloads.
   - Use `NotIn` or `DoesNotExist` to avoid unsuitable nodes.
5. **Monitor and Debug**:
   - Check pod placement: `kubectl get pods -o wide`.
   - Debug issues: `kubectl describe pod`.
6. **Combine with Other Features**:
   - Use taints/tolerations to complement affinity rules.
   - Integrate with resource limits for optimal placement.
7. **Plan for Scalability**:
   - Use node affinity in large clusters with dynamic node pools.
   - Anticipate future `RequiredDuringExecution` types for dynamic environments.

---

## 8. Advanced Considerations
- **Performance Impact**:
  - Node selectors have minimal overhead due to simple matching.
  - Complex node affinity rules (e.g., multiple terms, many nodes) may increase scheduler latency in large clusters.
  - **Mitigation**: Limit the number of terms and use specific labels.
- **Dynamic Clusters**:
  - Auto-scaling clusters (e.g., AWS EKS, GKE) may add/remove nodes, changing available labels.
  - **Solution**: Use `preferred` affinity or monitor node labels dynamically.
- **Multi-Cloud/Region Deployments**:
  - Use node affinity to prefer nodes in low-latency regions or avoid high-cost regions.
  - Example: Prefer `region=us-east` over `region=eu-west`.
- **Testing and Validation**:
  - Simulate scheduling failures by removing labels or applying taints.
  - Use `kubectl explain pod.spec.affinity` to understand fields.
- **Security Implications**:
  - Ensure sensitive workloads (e.g., payment processing) run on trusted nodes (e.g., `security=high`).
  - Combine with RBAC and network policies for isolation.

---

## 9. Debugging Tips
- **Pod Pending**:
  - Check node labels: `kubectl get nodes --show-labels`.
  - Check pod events: `kubectl describe pod <pod-name>`.
  - Verify YAML syntax and logic.
- **Unexpected Placement**:
  - Check for conflicting constraints (taints, resource limits, pod anti-affinity).
  - Verify weights in `preferred` affinity rules.
- **Validation Errors**:
  - Test YAML: `kubectl apply --dry-run=client`.
  - Avoid invalid combinations (e.g., `values` with `Exists`).
- **Dynamic Label Changes**:
  - Monitor node labels after changes: `kubectl get nodes --show-labels`.
  - Use `preferred` affinity for resilience.

---

## 10. Example Workflow
- **Scenario**: Deploy a machine learning application requiring GPUs, preferring `us-east` but allowing `us-west` as a fallback.
- **Cluster Setup**:
  - `node1`: `hardware=gpu, region=us-east`
  - `node2`: `hardware=gpu, region=us-west`
  - `node3`: `hardware=cpu, region=us-east`
- **Steps**:
  1. Label nodes:
     ```bash
     kubectl label nodes node1 hardware=gpu region=us-east
     kubectl label nodes node2 hardware=gpu region=us-west
     kubectl label nodes node3 hardware=cpu region=us-east
     ```
  2. Create `ml-pod.yaml`:
     ```yaml
     apiVersion: v1
     kind: Pod
     metadata:
       name: ml-pod
     spec:
       containers:
       - name: ml-container
         image: tensorflow/tensorflow:latest-gpu
       affinity:
         nodeAffinity:
           requiredDuringSchedulingIgnoredDuringExecution:
             nodeSelectorTerms:
             - matchExpressions:
               - key: hardware
                 operator: In
                 values:
                 - gpu
           preferredDuringSchedulingIgnoredDuringExecution:
           - weight: 80
             preference:
               matchExpressions:
               - key: region
                 operator: In
                 values:
                 - us-east
           - weight: 20
             preference:
               matchExpressions:
               - key: region
                 operator: In
                 values:
                 - us-west
     ```
  3. Apply and verify:
     ```bash
     kubectl apply -f ml-pod.yaml
     kubectl get pods -o wide
     ```
     **Output** (prefers `node1` due to `us-east`):
     ```
     NAME     READY   STATUS    NODE
     ml-pod   1/1     Running   node1
     ```
  4. Test fallback:
     - Remove `node1`’s GPU label: `kubectl label nodes node1 hardware-`
     - Reapply: Pod schedules on `node2` (`us-west`).

