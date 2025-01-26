### **Resource Quotas in Kubernetes: Comprehensive Notes**

Resource quotas in Kubernetes are a mechanism to manage and limit resource usage within a namespace. They ensure fair resource allocation among multiple users or teams sharing a cluster. Below is a detailed explanation of resource quotas, their types, and examples to help you understand the concept.

---

### **1. Why Resource Quotas?**
When multiple users or teams share a Kubernetes cluster, there is a risk that one team might consume more than its fair share of resources (e.g., CPU, memory, storage). Resource quotas help administrators:
- Limit resource consumption per namespace.
- Prevent resource exhaustion.
- Ensure fair usage across teams.

---

### **2. How Resource Quotas Work**
- **Namespaces**: Different teams work in different namespaces. Resource quotas are applied at the namespace level.
- **ResourceQuota Object**: Administrators create a `ResourceQuota` object in each namespace to define constraints.
- **Resource Tracking**: When users create resources (e.g., pods, services), the quota system tracks usage to ensure it does not exceed the defined limits.
- **Enforcement**: If a resource creation or update violates the quota, the request fails with an HTTP `403 FORBIDDEN` error, explaining the violated constraint.

---

### **3. Types of Resource Quotas**
Resource quotas can limit:
1. **Compute Resources** (e.g., CPU, memory).
2. **Storage Resources** (e.g., persistent storage, ephemeral storage).
3. **Object Counts** (e.g., number of pods, services, secrets).

---

### **4. Compute Resource Quota**
Compute resource quotas limit the total amount of CPU, memory, and other compute resources that can be requested in a namespace.

#### **Supported Resource Types**
| Resource Name          | Description                                                                 |
|-------------------------|-----------------------------------------------------------------------------|
| `limits.cpu`            | Sum of CPU limits across all pods in a non-terminal state.                  |
| `limits.memory`         | Sum of memory limits across all pods in a non-terminal state.               |
| `requests.cpu`          | Sum of CPU requests across all pods in a non-terminal state.                |
| `requests.memory`       | Sum of memory requests across all pods in a non-terminal state.             |
| `hugepages-<size>`      | Number of huge page requests of a specific size across all pods.            |
| `cpu`                   | Same as `requests.cpu`.                                                     |
| `memory`                | Same as `requests.memory`.                                                  |

#### **Example**
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
  namespace: team-a
spec:
  hard:
    requests.cpu: "10"
    requests.memory: "20Gi"
    limits.cpu: "20"
    limits.memory: "40Gi"
```
- This quota limits Team A to a maximum of 10 CPU requests, 20Gi memory requests, 20 CPU limits, and 40Gi memory limits.

---

### **5. Resource Quota for Extended Resources**
Extended resources (e.g., GPUs) can also be limited using quotas. Unlike CPU and memory, extended resources do not allow overcommitment, so only `requests` are supported.

#### **Example**
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: gpu-resources
  namespace: team-b
spec:
  hard:
    requests.nvidia.com/gpu: "4"
```
- This quota limits Team B to a maximum of 4 GPUs.

---

### **6. Storage Resource Quota**
Storage quotas limit the total amount of storage resources that can be requested in a namespace. They can also be scoped by storage class.

#### **Supported Resource Types**
| Resource Name                                      | Description                                                                 |
|----------------------------------------------------|-----------------------------------------------------------------------------|
| `requests.storage`                                 | Sum of storage requests across all persistent volume claims (PVCs).         |
| `persistentvolumeclaims`                           | Total number of PVCs in the namespace.                                      |
| `<storage-class-name>.storageclass.storage.k8s.io/requests.storage` | Sum of storage requests for PVCs associated with a specific storage class.  |
| `<storage-class-name>.storageclass.storage.k8s.io/persistentvolumeclaims` | Total number of PVCs associated with a specific storage class.              |

#### **Example**
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: storage-resources
  namespace: team-c
spec:
  hard:
    requests.storage: "1Ti"
    gold.storageclass.storage.k8s.io/requests.storage: "500Gi"
    bronze.storageclass.storage.k8s.io/requests.storage: "100Gi"
```
- This quota limits Team C to a total of 1Ti of storage, with 500Gi for the `gold` storage class and 100Gi for the `bronze` storage class.

---

### **7. Object Count Quota**
Object count quotas limit the number of specific Kubernetes objects (e.g., pods, services, secrets) that can be created in a namespace.

#### **Supported Resource Types**
| Resource Name          | Description                                                                 |
|-------------------------|-----------------------------------------------------------------------------|
| `count/pods`            | Total number of non-terminal pods in the namespace.                         |
| `count/services`        | Total number of services in the namespace.                                  |
| `count/secrets`         | Total number of secrets in the namespace.                                   |
| `count/configmaps`      | Total number of ConfigMaps in the namespace.                                |
| `count/persistentvolumeclaims` | Total number of PVCs in the namespace.                                      |

#### **Example**
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: object-counts
  namespace: team-d
spec:
  hard:
    count/pods: "100"
    count/services: "10"
    count/secrets: "50"
```
- This quota limits Team D to a maximum of 100 pods, 10 services, and 50 secrets.

---

### **8. Notes Section**
- **CPU and Memory Quotas**: If a quota is enforced for CPU or memory, every new pod must specify resource requests or limits. Otherwise, the pod creation will be rejected.
- **Ephemeral Storage**: Quotas for ephemeral storage count container logs, which can lead to unexpected pod evictions if the quota is exceeded.
- **Object Count Quotas**: These are useful for preventing resource exhaustion, such as too many secrets or pods consuming cluster resources.

---

### **9. Example Scenario**
Imagine a cluster shared by three teams: Team A, Team B, and Team C. To ensure fair usage:
- **Team A** is limited to 10 CPU requests, 20Gi memory requests, and 100 pods.
- **Team B** is limited to 4 GPUs and 50 secrets.
- **Team C** is limited to 1Ti of storage, with 500Gi for the `gold` storage class.

By defining resource quotas, the administrator ensures that no single team can monopolize cluster resources.

---

### **10. Key Takeaways**
- Resource quotas are applied at the namespace level.
- They can limit compute resources, storage resources, and object counts.
- Quotas ensure fair resource allocation and prevent resource exhaustion.
- Always specify resource requests and limits for CPU and memory when quotas are enabled.

---

By understanding and implementing resource quotas, administrators can effectively manage resource usage in multi-tenant Kubernetes clusters.
