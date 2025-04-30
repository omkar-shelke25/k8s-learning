
---

# In-Depth Notes on Kubernetes Network Policies

**Kubernetes Network Policies** are critical for securing pod-to-pod communication by controlling **Ingress** (incoming) and **Egress** (outgoing) traffic. These notes provide a deep dive into their concepts, implementation, and use cases, tailored to a three-tier application. We’ll include diagrams with icons, tables, and practical examples to ensure clarity.

---

## 1. Networking and Security Fundamentals

### 1.1 Three-Tier Application Overview
Consider a traditional three-tier application:
- **🌐 Web Server**: Serves user requests on **port 80** (HTTP).
- **⚙️ App Server**: Processes back-end logic on **port 5000**.
- **🗄️ Database Server**: Manages data on **port 3306** (e.g., MySQL).

#### Traffic Flow
The user request flows as follows:
1. User → Web Server (**port 80**)
2. Web Server → App Server (**port 5000**)
3. App Server → Database Server (**port 3306**)
4. Response: Database → App Server → Web Server → User

### 1.2 Key Concepts: Ingress and Egress
- **🔽 Ingress**: Incoming traffic to a component (e.g., user requests to web server on port 80).
- **🔼 Egress**: Outgoing traffic from a component (e.g., web server to app server on port 5000).
- **🔄 Responses**: Return traffic (e.g., database to app server) is not classified as Ingress or Egress; it follows the initiated request’s path.

#### Traffic Rules Table
| **Component**      | **Ingress**                     | **Egress**                      |
|--------------------|----------------------------------|----------------------------------|
| 🌐 Web Server      | From User on **port 80**        | To App Server on **port 5000**  |
| ⚙️ App Server      | From Web Server on **port 5000**| To Database on **port 3306**    |
| 🗄️ Database Server | From App Server on **port 3306**| None                            |

### 1.3 Traffic Flow Diagram with Icons
```
[👤 User] ----(Port 80)----> [🌐 Web Server] ----(Port 5000)----> [⚙️ App Server] ----(Port 3306)----> [🗄️ Database]
   | 🔼 Egress             | 🔽 Ingress        | 🔼 Egress        | 🔽 Ingress       | 🔼 Egress        | 🔽 Ingress
   |                       |                  |                 |                 |                 |
   |<----(Response)----    |<----(Response)----    |<----(Response)----    |
```

- **Icons**: 
  - 👤 = User
  - 🌐 = Web Server
  - ⚙️ = App Server
  - 🗄️ = Database
  - 🔼 = Egress
  - 🔽 = Ingress
- **Solid Arrows**: Initiated traffic (Ingress/Egress).
- **Dotted Arrows**: Response traffic (not controlled by policies).

---

## 2. Kubernetes Networking Basics

### 2.1 Cluster Components
- **🖥️ Nodes**: Physical or virtual machines in the cluster, each with an IP address.
- **📦 Pods**: Smallest deployable units, each with a unique IP, running containers.
- **🔗 Services**: Stable endpoints to access pods, abstracting pod IPs.
- **🌐 Cluster Networking**: A virtual private network (VPN) enables pod-to-pod communication, managed by plugins (e.g., Calico, Flannel, Weave Net).

### 2.2 Default Behavior: "All Allow"
- By default, Kubernetes allows all pods to communicate freely:
  - Any pod can access any other pod or service.
- **Security Risk**: In our application:
  - Web pod (`app: web`) can directly access Database pod (`app: database`), bypassing App pod (`app: app-server`).
  - This is insecure for production.

### 2.3 Goal of Network Policies
- Use **🔒 Network Policies** to enforce least-privilege access.
- **Example Objective**: Allow Database pod to accept **Ingress** only from App Server pod on **port 3306**, blocking other traffic (e.g., from Web pod).

---

## 3. Deep Dive into Network Policies

### 3.1 What Are Network Policies?
- Kubernetes resources in the `networking.k8s.io/v1` API group.
- Control **Ingress** and **Egress** traffic using:
  - **🏷️ Labels and Selectors**: Identify target pods and allowed sources/destinations.
  - **🔢 Ports and Protocols**: Specify allowed protocols (e.g., TCP) and ports.
  - **🌍 IP Blocks**: Allow/deny traffic from specific IP ranges (e.g., external users).
- Enforced by the cluster’s networking plugin (e.g., Calico).

### 3.2 How Network Policies Work
1. **🏷️ Label Pods**: Assign labels (e.g., `app: database`).
2. **📝 Define Policy**: Create a YAML file specifying:
   - `podSelector`: Target pods.
   - `policyTypes`: Ingress, Egress, or both.
   - `ingress`/`egress`: Allowed sources/destinations and ports.
3. **🚀 Apply Policy**: Use `kubectl apply`.
4. **🔍 Enforcement**: Networking plugin applies the rules.

### 3.3 Example Scenario
- **Objective**: Restrict Database pod to accept **Ingress** only from App Server pod on **port 3306**.
- **Pod Labels**:
  - 🌐 Web Server pod: `app: web`
  - ⚙️ App Server pod: `app: app-server`
  - 🗄️ Database pod: `app: database`

### 3.4 Network Policy YAML for Database
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: app-server
      ports:
        - protocol: TCP
          port: 3306
```

#### Breakdown
- **apiVersion**: `networking.k8s.io/v1` – API group.
- **kind**: `NetworkPolicy` – Resource type.
- **metadata**:
  - `name: db-policy` – Policy name.
  - `namespace: default` – Namespace scope.
- **spec**:
  - **podSelector**: Targets `app: database`.
  - **policyTypes**: Applies to **Ingress**.
  - **ingress**:
    - **from**: Allows `app: app-server`.
    - **ports**: TCP port 3306.

#### Apply
```bash
kubectl apply -f db-policy.yaml
```

#### Effect
- **✅ Allowed**: App Server pod → Database pod on port 3306.
- **🚫 Blocked**: Web Server pod → Database pod.

### 3.5 Complete Network Policies
To secure the entire application:
#### Web Server Policy
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - ipBlock:
            cidr: 0.0.0.0/0  # External users
      ports:
        - protocol: TCP
          port: 80
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: app-server
      ports:
        - protocol: TCP
          port: 5000
```

#### App Server Policy
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: app-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: app-server
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: web
      ports:
        - protocol: TCP
          port: 5000
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: database
      ports:
        - protocol: TCP
          port: 3306
```

#### Policy Summary Table
| **Pod**            | **Ingress**                     | **Egress**                      | **Policy Name** |
|--------------------|----------------------------------|----------------------------------|-----------------|
| 🌐 Web Server      | Port 80 (external)              | Port 5000 (to App Server)       | web-policy      |
| ⚙️ App Server      | Port 5000 (from Web Server)     | Port 3306 (to Database)         | app-policy      |
| 🗄️ Database Server | Port 3306 (from App Server)     | None                            | db-policy       |

---

## 4. Workflow for Managing Ingress and Egress

### 4.1 Step 1: Map Traffic
- Identify required traffic:
  - 🌐 Web Server: 🔽 Ingress (port 80), 🔼 Egress (to port 5000).
  - ⚙️ App Server: 🔽 Ingress (port 5000), 🔼 Egress (to port 3306).
  - 🗄️ Database: 🔽 Ingress (port 3306).

### 4.2 Step 2: Label Pods
- Assign labels:
  - `app: web`
  - `app: app-server`
  - `app: database`

### 4.3 Step 3: Define Policies
- Write YAML files for each pod (see Section 3.5).

### 4.4 Step 4: Apply Policies
```bash
kubectl apply -f web-policy.yaml
kubectl apply -f app-policy.yaml
kubectl apply -f db-policy.yaml
```

### 4.5 Step 5: Test Connectivity
- **✅ Allowed**:
  - `kubectl exec -it web-pod -- curl app-service:5000`
  - `kubectl exec -it app-pod -- curl db-service:3306`
- **🚫 Blocked**:
  - `kubectl exec -it web-pod -- curl db-service:3306`

### 4.6 Step 6: Default Deny Policy
- Block all unspecified traffic:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: default
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```
- Apply: `kubectl apply -f default-deny.yaml`

---

## 5. Common Use Cases for Network Policies

### 5.1 Use Case 1: Securing Multi-Tier Applications
- **Scenario**: Protect a database pod in a multi-tier app (like above).
- **Solution**: Restrict Ingress to specific pods (e.g., App Server only).

### 5.2 Use Case 2: Namespace Isolation
- **Scenario**: Prevent pods in different namespaces from communicating unless explicitly allowed.
- **Example Policy**:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
  namespace: app
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: app
```

### 5.3 Use Case 3: External Traffic Control
- **Scenario**: Allow external traffic to a front-end service (e.g., Web Server) while restricting internal access.
- **Example**: See Web Server policy (allows `0.0.0.0/0` on port 80).

### 5.4 Use Case 4: Egress Restriction
- **Scenario**: Prevent pods from accessing external malicious sites.
- **Example Policy**:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-egress
spec:
  podSelector:
    matchLabels:
      app: app-server
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: 10.0.0.0/16  # Allow internal cluster IPs
      ports:
        - protocol: TCP
          port: 3306
```

### Use Cases Table
| **Use Case**                | **Description**                                   | **Example Policy**                  |
|-----------------------------|--------------------------------------------------|-------------------------------------|
| Multi-Tier App Security     | Restrict pod access in layered apps              | Database Ingress from App Server   |
| Namespace Isolation         | Limit cross-namespace communication              | Allow same-namespace traffic       |
| External Traffic Control    | Allow external access to specific services       | Web Server Ingress from 0.0.0.0/0  |
| Egress Restriction          | Prevent pods from accessing external sites       | Restrict Egress to cluster IPs     |

---

## 6. Diagram with Icons and Policy Enforcement

```
[👤 User] ----(Port 80)----> [🌐 Web Server Pod] ----(Port 5000)----> [⚙️ App Server Pod] ----(Port 3306)----> [🗄️ Database Pod]
   | 🔼 Egress             | 🔽 Ingress         | 🔼 Egress         | 🔽 Ingress        | 🔼 Egress         | 🔽 Ingress
   |                       | (app: web)         | (app: app-server) |                   | (app: database)   |
   |                       |                    |                   |                   |                   |
   |<----(Response)----    |<----(Response)----     |<----(Response)----     |
   |                       |                    |                   |                   |
   |                       +--------------------X-------------------X------------------->X 🚫
   |                       | Direct Egress to Database (Blocked by 🔒 Network Policy) |
   +-----------------------+--------------------+
                           | 🔒 Network Policy   |
                           | for Database        |
                           | Allows 🔽 Ingress   |
                           | from App Server     |
                           | on Port 3306        |
                           +--------------------+
```

- **Icons**:
  - 👤 = User
  - 🌐 = Web Server
  - ⚙️ = App Server
  - 🗄️ = Database
  - 🔼 = Egress
  - 🔽 = Ingress
  - 🔒 = Network Policy
  - 🚫 = Blocked Traffic
- **Solid Arrows**: Allowed traffic.
- **Red X**: Blocked traffic (e.g., Web Server to Database).
- **Dotted Arrows**: Response traffic.

---

## 7. Practical Deployment Example

### 7.1 Pod Definitions
#### Web Server Pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-pod
  labels:
    app: web
spec:
  containers:
    - name: nginx
      image: nginx
      ports:
        - containerPort: 80
```

#### App Server Pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
  labels:
    app: app-server
spec:
  containers:
    - name: app
      image: my-app-image
      ports:
        - containerPort: 5000
```

#### Database Pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: db-pod
  labels:
    app: database
spec:
  containers:
    - name: mysql
      image: mysql:5.7
      ports:
        - containerPort: 3306
      env:
        - name: MYSQL_ROOT_PASSWORD
          value: "password"
```

### 7.2 Apply Pods
```bash
kubectl apply -f web-pod.yaml
kubectl apply -f app-pod.yaml
kubectl apply -f db-pod.yaml
```

### 7.3 Apply Network Policies
Use policies from Section 3.5 (`web-policy.yaml`, `app-policy.yaml`, `db-policy.yaml`).

### 7.4 Test Connectivity
- **✅ Allowed**:
  - `kubectl exec -it web-pod -- curl app-service:5000`
  - `kubectl exec -it app-pod -- curl db-service:3306`
- **🚫 Blocked**:
  - `kubectl exec -it web-pod -- curl db-service:3306`

---

## 8. Important Considerations

- **🌐 Networking Plugin**: Must support Network Policies (e.g., Calico, Weave Net). **Flannel** does not, rendering policies ineffective.
- **🔄 Response Traffic**: Not controlled by Network Policies; only initiated traffic is affected.
- **🛠️ Testing**: Use `kubectl exec` with `curl` or `netcat` to verify rules.
- **📋 Best Practices**:
  - Use consistent labels (e.g., `app: <name>`).
  - Apply specific allow policies before default deny.
  - Document and test in a non-production environment.

---

## 9. Conclusion

Kubernetes Network Policies are essential for securing pod-to-pod communication in a cluster. By defining **Ingress** and **Egress** rules, you can enforce least-privilege access, as demonstrated in the three-tier application. The workflow—mapping traffic, labeling pods, defining policies, applying, and testing—ensures robust security. Common use cases include securing multi-tier apps, isolating namespaces, controlling external traffic, and restricting Egress. For further learning, explore the [Kubernetes Network Policy documentation](https://kubernetes.io/docs/concepts/services-networking/network-policies/
