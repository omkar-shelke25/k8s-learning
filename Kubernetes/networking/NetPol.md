

# Kubernetes NetworkPolicies: A Deep Dive with DNS Handling

## Table of Contents
1. [Introduction to NetworkPolicies](#1-introduction-to-networkpolicies)
2. [Why NetworkPolicies Matter](#2-why-networkpolicies-matter)
3. [Default Behavior Without NetworkPolicies](#3-default-behavior-without-networkpolicies)
4. [NetworkPolicy Components and Scope](#4-networkpolicy-components-and-scope)
5. [DNS in Kubernetes](#5-dns-in-kubernetes)
   - [How DNS Works in Kubernetes](#51-how-dns-works-in-kubernetes)
   - [Why DNS Needs to Be Allowed](#52-why-dns-needs-to-be-allowed)
   - [Allowing DNS in NetworkPolicies](#53-allowing-dns-in-networkpolicies)
6. [Production Scenario: 3-Tier Application](#6-production-scenario-3-tier-application)
   - [Policy 1: Web Tier (Ingress + Egress)](#61-policy-1-web-tier-ingress--egress)
   - [Policy 2: API Tier (Ingress + Egress)](#62-policy-2-api-tier-ingress--egress)
   - [Policy 3: DB Tier (Ingress + Egress)](#63-policy-3-db-tier-ingress--egress)
   - [Policy 4: Global DNS Access](#64-policy-4-global-dns-access)
   - [Diagram: How NetworkPolicies Work](#65-diagram-how-networkpolicies-work)
7. [Troubleshooting DNS and NetworkPolicy Issues](#7-troubleshooting-dns-and-networkpolicy-issues)
8. [Best Practices for Production](#8-best-practices-for-production)
9. [Testing NetworkPolicies](#9-testing-networkpolicies)
10. [Common Mistakes and Fixes](#10-common-mistakes-and-fixes)
11. [Summary Table](#11-summary-table)

---

## 1. Introduction to NetworkPolicies

A **NetworkPolicy** is a Kubernetes resource that controls network traffic to and from pods at the IP and port level (Layer 3/4). It acts as a **firewall**, enabling fine-grained control over pod-to-pod, pod-to-external, and namespace-level communication.

- **Purpose**: Enhance security, enforce compliance, and isolate workloads.
- **Analogy**: NetworkPolicies are security guards allowing only authorized traffic.

---

## 2. Why NetworkPolicies Matter

### Security & Isolation
- **Prevent Lateral Movement**: Limit compromised pod impact.
- **Isolate Sensitive Workloads**: Restrict access to databases or secrets.
- **Namespace Segregation**: Control multi-tenant cluster communication.

### Compliance
- **Regulatory Standards**: Meet PCI DSS, HIPAA, or GDPR requirements.
- **Auditability**: Provide declarative, auditable rules.

### Operational Control
- **Traffic Optimization**: Reduce unnecessary traffic.
- **Debugging**: Simplify troubleshooting with explicit rules.

---

## 3. Default Behavior Without NetworkPolicies

- **All traffic allowed** by default (open communication).
- Pods can communicate with:
  - Other pods in the same namespace.
  - Pods in other namespaces.
  - External IPs (e.g., internet).
- **Effect of NetworkPolicy**:
  - Implicit deny: All traffic not explicitly allowed is blocked.
  - Whitelist approach for `Ingress` and/or `Egress`.

---

## 4. NetworkPolicy Components and Scope

| Field | Description |
|-------|-------------|
| `podSelector` | Selects pods (labels). Empty (`{}`) = all pods in namespace. |
| `policyTypes` | `Ingress`, `Egress`, or both. |
| `ingress` | Rules for incoming traffic (pods, namespaces, IPs). |
| `egress` | Rules for outgoing traffic (pods, namespaces, IPs). |
| `namespaceSelector` | Filters namespaces by labels (e.g., `name: backend`). |
| `ipBlock` | Allows/denies IP ranges (e.g., `10.0.0.0/24`). |
| `ports` | Specifies ports/protocols (e.g., TCP/8080, UDP/53). |

---

## 5. DNS in Kubernetes

### 5.1 How DNS Works in Kubernetes
- **DNS Server**: **CoreDNS** (or `kube-dns`) in `kube-system`.
- **DNS Names**:
  - Services: `<service-name>.<namespace>.svc.cluster.local` (e.g., `api.default.svc.cluster.local`).
  - Pods: `<pod-ip>.<namespace>.pod.cluster.local` (e.g., `10-244-0-1.default.pod.cluster.local`).
- **Protocol**: UDP/53 (TCP/53 for large responses).
- **Process**:
  1. Pod sends DNS query to CoreDNS.
  2. CoreDNS resolves to IP (e.g., Service ClusterIP).
  3. Pod uses IP to communicate.

### 5.2 Why DNS Needs to Be Allowed
- Egress NetworkPolicies block all outgoing traffic unless allowed.
- DNS queries (UDP/53 to CoreDNS) must be permitted for service discovery.
- Without DNS access, pods fail to resolve names, causing errors (e.g., `UnknownHostException`).

### 5.3 Allowing DNS in NetworkPolicies
#### Specific DNS Rule (Recommended)
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

#### Generic DNS Rule (Less Secure)
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-generic
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

**Recommendation**: Use specific rule for production to limit DNS to CoreDNS.

---

## 6. Production Scenario: 3-Tier Application

**Components** (in `default` namespace):
- **Web**: Frontend pods (port 80, `app: web`), communicates with API.
- **API**: Backend REST service (port 8080, `app: api`), communicates with DB.
- **DB**: PostgreSQL database (port 5432, `app: db`), accepts API connections.

**Services**:
- `web.default.svc.cluster.local` (ClusterIP, port 80)
- `api.default.svc.cluster.local` (ClusterIP, port 8080)
- `db.default.svc.cluster.local` (ClusterIP, port 5432)

**Requirements**:
- Web: Accepts external HTTP (port 80, e.g., via Ingress) and sends to API (port 8080).
- API: Accepts from Web (port 8080) and sends to DB (port 5432).
- DB: Accepts from API (port 5432).
- All pods need DNS resolution.
- Block unauthorized traffic (e.g., Web to DB).

### 6.1 Policy 1: Web Tier (Ingress + Egress)
- **Ingress**: Allow external traffic (port 80).
- **Egress**: Allow to API (port 8080) and CoreDNS (port 53).

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
        - namespaceSelector: {}  # Allow from any namespace (e.g., Ingress controller)
      ports:
        - protocol: TCP
          port: 80
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: api
      ports:
        - protocol: TCP
          port: 8080
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

### 6.2 Policy 2: API Tier (Ingress + Egress)
- **Ingress**: Allow from Web (port 8080).
- **Egress**: Allow to DB (port 5432) and CoreDNS (port 53).

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: api
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
          port: 8080
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: db
      ports:
        - protocol: TCP
          port: 5432
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

### 6.3 Policy 3: DB Tier (Ingress + Egress)
- **Ingress**: Allow from API (port 5432).
- **Egress**: Allow to CoreDNS (port 53, optional).

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: db
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: api
      ports:
        - protocol: TCP
          port: 5432
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

### 6.4 Policy 4: Global DNS Access
Allow DNS for all pods, simplifying individual policies.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-for-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

**Simplified Policies**: With the global DNS policy, remove DNS egress rules from Web, API, and DB policies. Example for Web:
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
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 80
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: api
      ports:
        - protocol: TCP
          port: 8080
```

### 6.5 Diagram: How NetworkPolicies Work

#### Diagram Description
The diagram visualizes the 3-tier application’s traffic flow with NetworkPolicies:
- **Nodes**:
  - **External Client**: Represents users or Ingress controller sending HTTP requests.
  - **Web Pod**: Labeled `app: web`, listens on port 80.
  - **API Pod**: Labeled `app: api`, listens on port 8080.
  - **DB Pod**: Labeled `app: db`, listens on port 5432.
  - **CoreDNS Pod**: In `kube-system`, listens on UDP/53 and TCP/53.
- **Arrows (Allowed Traffic)**:
  - External → Web (TCP/80, ingress allowed).
  - Web → API (TCP/8080, egress from Web, ingress to API).
  - API → DB (TCP/5432, egress from API, ingress to DB).
  - All Pods → CoreDNS (UDP/53, TCP/53, egress allowed).
- **Crossed-Out Arrows (Blocked Traffic)**:
  - Web → DB (TCP/5432, blocked by Web egress and DB ingress).
  - API → Web (TCP/80, blocked by API egress and Web ingress).
- **Annotations**:
  - Label each arrow with protocol/port and policy type (ingress/egress).
  - Highlight the `default` namespace for Web, API, DB, and `kube-system` for CoreDNS.

#### ASCII Diagram
```
+----------------+          +----------------+          +----------------+
| External Client|          |   Web Pod      |          |   API Pod      |
|                |---TCP/80-->| (app: web)     |---TCP/8080-->| (app: api)     |
|                |          |                |          |                |
+----------------+          +----------------+          +----------------+
                                    |                        |
                                    |                        |
                                    v                        v
                             +----------------+          +----------------+
                             |   DB Pod      |          | CoreDNS        |
                             | (app: db)     |<--TCP/5432--| (kube-system)  |
                             |                |          | (k8s-app: kube-dns) |
                             +----------------+          +----------------+
                                    |                        ^
                                    |                        |
                                    +---UDP/53, TCP/53------+
                                    (All Pods)

Blocked Traffic:
- Web --> DB (TCP/5432) [X]
- API --> Web (TCP/80) [X]
```

#### Mermaid Diagram (Markdown-Compatible)
For rendering in tools like GitHub or VS Code with Mermaid plugins, use this code:

```mermaid
graph TD
    A[External Client] -->|TCP/80 (Ingress)| B[Web Pod<br>app: web]
    B -->|TCP/8080 (Egress)| C[API Pod<br>app: api]
    C -->|TCP/5432 (Egress)| D[DB Pod<br>app: db]
    B -->|UDP/53, TCP/53 (Egress)| E[CoreDNS<br>kube-system<br>k8s-app: kube-dns]
    C -->|UDP/53, TCP/53 (Egress)| E
    D -->|UDP/53, TCP/53 (Egress)| E
    B -.-x|TCP/5432 (Blocked)| D
    C -.-x|TCP/80 (Blocked)| B
    subgraph default namespace
        B
        C
        D
    end
    subgraph kube-system namespace
        E
    end
```

**Rendering Instructions**:
- Copy the Mermaid code into a Markdown file (e.g., `networkpolicy-notes.md`).
- View in a Mermaid-compatible editor (e.g., GitHub, VS Code with Mermaid Preview).
- Alternatively, use an online Mermaid editor like [mermaid.live](https://mermaid.live/).

#### Creating a Visual Diagram
To create a polished diagram:
1. **Tool**: Use Draw.io, Lucidchart, or Excalidraw.
2. **Steps**:
   - Add rectangles for External Client, Web Pod, API Pod, DB Pod, and CoreDNS.
   - Draw solid arrows for allowed traffic (label with protocol/port and ingress/egress).
   - Draw dashed/red arrows with an “X” for blocked traffic.
   - Group Web, API, DB in a `default` namespace box; CoreDNS in a `kube-system` box.
   - Add labels (e.g., `app: web`, `TCP/8080`).
3. **Export**: Save as PNG/SVG and embed in documentation, or link in the Markdown.

---

## 7. Troubleshooting DNS and NetworkPolicy Issues

1. **Verify DNS**:
   ```bash
   kubectl run -it --rm test --image=busybox -n default -- /bin/sh
   nslookup api.default.svc.cluster.local
   ```
   - Expect: Resolved IP (e.g., `10.100.0.1`).
   - Fail: Check UDP/53 egress to `kube-system`.

2. **Check CoreDNS Logs**:
   ```bash
   kubectl logs -n kube-system -l k8s-app=kube-dns
   ```

3. **Inspect Policies**:
   ```bash
   kubectl get networkpolicy -n default
   kubectl describe networkpolicy web-policy -n default
   ```

4. **Verify Labels**:
   ```bash
   kubectl get pods -n default --show-labels
   kubectl get namespace --show-labels
   ```

5. **Test Connectivity**:
   - Web to API:
     ```bash
     kubectl exec -it <web-pod> -n default -- curl http://api.default.svc.cluster.local:8080
     ```
   - API to DB:
     ```bash
     kubectl exec -it <api-pod> -n default -- psql -h db.default.svc.cluster.local -U user
     ```
   - Blocked (Web to DB):
     ```bash
     kubectl exec -it <web-pod> -n default -- curl http://db.default.svc.cluster.local:5432
     ```

6. **Check CNI**:
   - Ensure CNI supports NetworkPolicies (e.g., Calico, Cilium).
   ```bash
   kubectl get nodes -o wide
   ```

---

## 8. Best Practices for Production

1. **Meaningful Labels**:
   ```yaml
   metadata:
     labels:
       app: web
       tier: frontend
   ```

2. **Minimize Overlap**: Use global DNS policy.
3. **Namespace Isolation**:
   ```yaml
   namespaceSelector:
     matchLabels:
       name: backend
   ```

4. **Monitor/Audit**:
   ```bash
   kubectl get networkpolicy -n default -o yaml
   kubectl logs -n kube-system -l k8s-app=kube-dns
   ```

5. **Start Restrictive**: Deny all, then allow specific.
6. **Document**:
   ```yaml
   # Allow Web to API
   ```

7. **Test Incrementally**:
   ```bash
   kubectl apply -f policy.yaml --dry-run=client
   ```

8. **Secure Ingress Controllers**:
   ```yaml
   - from:
       - namespaceSelector:
           matchLabels:
             name: ingress-nginx
   ```

9. **CNI Features**: Use Calico/Cilium for observability.

---

## 9. Testing NetworkPolicies

1. **Test Pod**:
   ```bash
   kubectl run -it --rm test --image=busybox -n default -- /bin/sh
   ```

2. **DNS**:
   ```bash
   nslookup api.default.svc.cluster.local
   ```

3. **Web Access**:
   ```bash
   curl http://web.default.svc.cluster.local
   ```

4. **Web to API**:
   ```bash
   kubectl exec -it <web-pod> -n default -- curl http://api.default.svc.cluster.local:8080
   ```

.ConcurrentModificationException: Failed to update node status: Operation cannot be fulfilled on nodes "<node-name>": the object has been modified; please apply your changes to the latest version and try again
5. **API to DB**:
   ```bash
   kubectl exec -it <api-pod> -n default -- psql -h db.default.svc.cluster.local -U user
   ```

6. **Blocked Traffic**:
   ```bash
   kubectl exec -it <web-pod> -n default -- curl http://db.default.svc.cluster.local:5432
   ```

7. **CNI Tools**:
   - Calico: `calicoctl get networkpolicy`
   - Cilium: `cilium monitor`

---

## 10. Common Mistakes and Fixes

| Mistake | Fix |
|---------|-----|
| Forgetting DNS | Add `UDP/53`, `TCP/53` to `kube-system`/`k8s-app=kube-dns`. |
| Missing ingress | Add `ingress` for receiving pods. |
| Empty `podSelector` | Use specific labels (e.g., `app: web`). |
| No policies | Apply at least one policy per namespace. |
| Incorrect labels | Verify with `kubectl get pods --show-labels`. |
| Non-compatible CNI | Use Calico/Cilium. |
| Overlapping policies | Consolidate rules. |

---

## 11. Summary Table

| Topic | Description |
|-------|-------------|
| **DNS Port** | UDP/53, TCP/53 |
| **DNS Traffic** | Egress to CoreDNS (`kube-system`) |
| **Needed in Policy?** | Yes for egress with service discovery |
| **Ingress Use** | Restrict incoming (e.g., Web to API) |
| **Egress Use** | Restrict outgoing (e.g., API to DB) |
| **Must-Haves** | Ingress/egress rules, global DNS, namespace isolation |
| **Default** | All traffic allowed without policies |
| **Tools** | `nslookup`, `kubectl logs`, `kubectl describe` |
| **CNI** | Calico, Cilium, etc. |

---
