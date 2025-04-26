
# 🚀 Kustomize Deep Notes: Updating Dictionaries (New Example - `Service`) 

---

## 📖 New Overview: Patching a Kubernetes **Service**
In this example, we'll **patch a Kubernetes Service** to:
- **Update** a label (`tier: backend` → `tier: middleware`),
- **Add** a new label (`team: devops`),
- **Remove** an existing label (`environment: staging`).

We’ll use **both JSON 6902** and **Strategic Merge** methods, but **this time on a `Service` resource**.

---

## 🗂️ New Directory Structure

```
k8s/
├── base/
│   ├── my-service.yaml
│   ├── kustomization.yaml
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   ├── patches/
│   │   │   ├── service-label-patch.yaml
```

- **base/my-service.yaml**:
  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: my-service
    labels:
      tier: backend
      environment: staging
  spec:
    selector:
      app: my-app
    ports:
      - protocol: TCP
        port: 80
        targetPort: 8080
  ```

- **base/kustomization.yaml**:
  ```yaml
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - my-service.yaml
  ```

---

# 🔍 1. JSON 6902 Patch for the Service

---

### ✏️ (a) Update an Existing Label (`tier`)
**Goal**: Change `tier: backend` → `tier: middleware`

**overlays/dev/kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
patches:
  - target:
      group: ""
      version: v1
      kind: Service
      name: my-service
    patch: |-
      - op: replace
        path: /metadata/labels/tier
        value: middleware
```

**Result**:
```yaml
metadata:
  labels:
    tier: middleware
    environment: staging
```

---

### ➕ (b) Add a New Label (`team`)
**Goal**: Add `team: devops`

**overlays/dev/kustomization.yaml** (continuing patch):
```yaml
patches:
  - target:
      group: ""
      version: v1
      kind: Service
      name: my-service
    patch: |-
      - op: replace
        path: /metadata/labels/tier
        value: middleware
      - op: add
        path: /metadata/labels/team
        value: devops
```

**Result**:
```yaml
metadata:
  labels:
    tier: middleware
    environment: staging
    team: devops
```

---

### ❌ (c) Remove an Existing Label (`environment`)
**Goal**: Remove `environment: staging`

**Full patch in overlays/dev/kustomization.yaml**:
```yaml
patches:
  - target:
      group: ""
      version: v1
      kind: Service
      name: my-service
    patch: |-
      - op: replace
        path: /metadata/labels/tier
        value: middleware
      - op: add
        path: /metadata/labels/team
        value: devops
      - op: remove
        path: /metadata/labels/environment
```

**Result**:
```yaml
metadata:
  labels:
    tier: middleware
    team: devops
```

---

# 🌍 2. Strategic Merge Patch for the Service

---

### ✏️ (a) Update `tier`, ➕ Add `team`, ❌ Remove `environment`

**overlays/dev/patches/service-label-patch.yaml**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  labels:
    tier: middleware
    team: devops
    environment: null
```

**overlays/dev/kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
patchesStrategicMerge:
  - patches/service-label-patch.yaml
```

**Result after patch**:
```yaml
metadata:
  labels:
    tier: middleware
    team: devops
```

---

# 📊 New Summary Table (Service Example)

| Operation         | JSON 6902 Patch                                          | Strategic Merge Patch                        |
|:------------------|:---------------------------------------------------------|:---------------------------------------------|
| **Update**         | `op: replace`, `/metadata/labels/tier`, value `middleware` | Overwrite `tier: middleware` in YAML         |
| **Add**            | `op: add`, `/metadata/labels/team`, value `devops`        | Add `team: devops` in YAML                   |
| **Remove**         | `op: remove`, `/metadata/labels/environment`              | Set `environment: null` in YAML              |

---

# 🔧 Applying and Verifying Patches (New Example)

**Go to overlay**:
```bash
cd k8s/overlays/dev
```

**Preview**:
```bash
kustomize build .
```

**Apply**:
```bash
kubectl apply -k .
```

**Verify**:
```bash
kubectl get service my-service -o jsonpath='{.metadata.labels}'
# Output: map[tier:middleware team:devops]
```

---

# 💡 New Tips

- **JSON 6902**:
  - Best for very fine-grained, automated changes (e.g., CI pipelines).
  - Double-check JSON Pointer paths like `/metadata/labels/team`.
- **Strategic Merge**:
  - Best for clean, human-friendly YAML edits.
  - Easy to manage when you change multiple labels at once.

---

# 🎯 Final Thought (New Example)

Patching **Services** (not just Deployments!) with **Kustomize** is simple and powerful.  
- **Use JSON 6902** when you want *exact*, *fine-grained* operations.
- **Use Strategic Merge** when you want *simple*, *YAML-based* changes.

> **Key to success**: Understand the resource structure, paths, and operation types!
