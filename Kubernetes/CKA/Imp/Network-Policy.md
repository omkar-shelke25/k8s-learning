# 🚦 Kubernetes NetworkPolicy – Complete Study Notes

## 1. What is a NetworkPolicy?

**Think of it as a firewall for Pods** - controls network traffic at the Pod level

**Key Points:**
- Works only for Pods (NOT Services or Nodes)
- Created within a specific namespace
- Can control traffic to/from same namespace, other namespaces, or external IPs
- Only works with CNI plugins that support NetworkPolicies (Calico, Cilium, etc.)

---

## 2. Ingress vs Egress Traffic

### Ingress (Incoming Traffic)
- Traffic **coming INTO** your Pods
- `from` = specifies WHO can send traffic (sources)
- `ports` = specifies which Pod ports can receive traffic

### Egress (Outgoing Traffic)  
- Traffic **going OUT FROM** your Pods
- `to` = specifies WHERE Pods can send traffic (destinations)
- `ports` = specifies which destination ports can be used

---

## 3. Default Behavior (Critical to Understand! ⚡)

### When NO NetworkPolicy exists:
- **All traffic allowed** (ingress + egress)

### When NetworkPolicy exists:

| Scenario | Ingress Behavior | Egress Behavior |
|----------|------------------|-----------------|
| No `ingress` section | **OPEN** to everyone | Controlled by egress rules |
| No `egress` section | Controlled by ingress rules | **OPEN** to everyone |
| `ingress: []` | **DENIED** from everyone | Controlled by egress rules |
| `egress: []` | Controlled by ingress rules | **DENIED** to everyone |
| Only ingress rules defined | **DENY by default**, allow only specified | **OPEN** to everyone |
| Only egress rules defined | **OPEN** to everyone | **DENY by default**, allow only specified |

### Memory Hook:
- **Missing section** = Open to all
- **Empty array `[]`** = Block everything  
- **Rules present** = Deny by default, allow only what's specified

---

## 4. Selectors and Traffic Control

### `podSelector`
```yaml
podSelector:
  matchLabels:
    app: web
```
- Selects Pods **within the same namespace**
- `podSelector: {}` = all Pods in the namespace

### `namespaceSelector`
```yaml
namespaceSelector:
  matchLabels:
    team: frontend
```
- Selects Pods from **other namespaces**
- Namespace must have the specified labels

### Combining Selectors
```yaml
from:
- namespaceSelector:
    matchLabels:
      team: frontend
  podSelector:
    matchLabels:
      app: client
```
- Allows traffic from Pods with `app=client` label in namespaces with `team=frontend` label

---

## 5. Ports Specification

```yaml
ports:
- protocol: TCP
  port: 80
- protocol: UDP
  port: 53
```

**If ports not specified** = All ports allowed for the matching from/to rules

---

## 6. Cross-Namespace Communication

### Same Namespace Pods:
```yaml
from:
- podSelector:
    matchLabels:
      app: frontend
```

### Other Namespace Pods:
```yaml
from:
- namespaceSelector:
    matchLabels:
      env: production
```

### Default Namespace:
- Not special - must be labeled to be selected
- `kubectl label ns default name=default`

---

## 7. External Traffic

### Allow External IPs:
```yaml
from:
- ipBlock:
    cidr: 192.168.1.0/24
    except:
    - 192.168.1.5/32
```

### Deny All External (only internal traffic):
```yaml
from:
- namespaceSelector: {}  # All namespaces
- podSelector: {}        # All pods in current namespace
```

---

## 8. Common Patterns

### 1. Deny All Traffic (Isolation)
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress: []
  egress: []
```

### 2. Allow Only Same Namespace
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
spec:
  podSelector: {}
  ingress:
  - from:
    - podSelector: {}
```

### 3. Three-Tier Application
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-netpol
spec:
  podSelector:
    matchLabels:
      tier: web
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from: []  # Allow from anywhere (internet)
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: api
    ports:
    - protocol: TCP
      port: 8080
```

---

## 9. CKAD/CKS Memory Hooks 🧠

| Symbol | Meaning |
|--------|---------|
| `{}` | Allow everything/Select all |
| `[]` | Block everything |
| Missing | Open to all (same + other namespaces + external) |
| `podSelector` | Same namespace only |
| `namespaceSelector` | Cross-namespace |
| No NetworkPolicy | Everything allowed |
| NetworkPolicy exists | Deny by default for defined traffic types |

---

## 10. Troubleshooting Tips

### Check if NetworkPolicy is applied:
```bash
kubectl get networkpolicy -A
kubectl describe networkpolicy <policy-name> -n <namespace>
```

### Verify Pod labels:
```bash
kubectl get pods --show-labels
```

### Check namespace labels:
```bash
kubectl get namespaces --show-labels
```

### Test connectivity:
```bash
# From inside a pod
kubectl exec -it <pod-name> -- nc -zv <target-ip> <port>
```

---

## 11. Complete Example

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: multi-tier-app
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    # Allow from frontend pods in same namespace
    - podSelector:
        matchLabels:
          app: frontend
    # Allow from monitoring namespace
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    # Allow to database pods in same namespace
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
  - to:
    # Allow to external logging service
    - ipBlock:
        cidr: 10.0.0.0/8
    ports:
    - protocol: TCP
      port: 514
```

**This policy:**
- Applies to Pods with `app=backend` label in `production` namespace
- **Ingress**: Allows traffic from frontend pods (same namespace) and monitoring namespace on port 8080
- **Egress**: Allows traffic to database pods (same namespace) on port 5432 and external logging on port 514
- **Blocks**: All other traffic not explicitly allowed

---

## 📝 Quick Reference Card

```
NO POLICY = Everything allowed
POLICY EXISTS = Deny by default for specified types
ingress: [] = Block all incoming
egress: [] = Block all outgoing
podSelector: {} = All pods in same namespace
namespaceSelector: {} = All namespaces
Missing section = Fully open
```
