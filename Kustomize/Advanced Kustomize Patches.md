

# 🚀 Advanced Kustomize Patches: Inline vs. Separate Files and Dictionary Operations

## 📖 Introduction: Expanding Patch Flexibility
Kustomize patches—whether JSON 6902 or Strategic Merge—offer precise control over Kubernetes resources. So far, we’ve defined patches inline within `kustomization.yaml`, but things can get complex as patch count grows. In this section, we’ll explore two ways to define patches (inline and separate files) and demonstrate how to manipulate dictionary keys (e.g., labels) with operations like replace, add, and remove. This added complexity unlocks powerful customization, so let’s dive in with practical examples.

---

## 🌟 Inline vs. Separate File Patches
Both JSON 6902 and Strategic Merge patches can be defined in two ways:
1. **Inline**: Directly in `kustomization.yaml`.
2. **Separate File**: In external YAML files referenced by `kustomization.yaml`.

### 🔍 Why Two Methods?
- **Inline**: Simple for small, one-off changes—keeps everything in one place.
- **Separate File**: Better for many patches or complex changes—avoids cluttering `kustomization.yaml`.

**Real-World Context**: Inline works for quick tweaks (e.g., one replica change), but separate files shine in large projects with dozens of patches.

---

## 🗂️ Base Config: A Deployment with Labels
Let’s use this Deployment as our starting point:

```
k8s/
├── deployment.yaml
├── kustomization.yaml
├── replica-patch.yaml  # For separate file examples
├── label-patch.yaml    # For separate file examples
```

- **deployment.yaml**:
  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: api-deployment
    labels:
      component: api
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: api
    template:
      metadata:
        labels:
          app: api
      spec:
        containers:
        - name: api
          image: my-api:latest
  ```

---

## 🛠️ JSON 6902 Patch: Inline and Separate File Examples

### 1. 🔖 Replace a Key (Inline)
**Goal**: Change `component: api` to `component: web`.

**kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
patches:
  - target:
      kind: Deployment
      name: api-deployment
    patch: |-
      - op: replace
        path: /metadata/labels/component
        value: web
```

**Output (Abridged)**:
```yaml
metadata:
  name: api-deployment
  labels:
    component: web
```

**Technical Breakdown**:
- **Target**: Matches `kind: Deployment`, `name: api-deployment`.
- **Patch**:
  - `op: replace`: Swaps the existing value.
  - `path: /metadata/labels/component`: Navigates to the `component` key in the `labels` dictionary (`root → metadata → labels → component`).
  - `value: web`: New value replaces `api`.

### 2. 🔖 Replace a Key (Separate File)
**kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
patches:
  - target:
      kind: Deployment
      name: api-deployment
    path: label-patch.yaml
```

**label-patch.yaml**:
```yaml
- op: replace
  path: /metadata/labels/component
  value: web
```

**Output**: Same as inline—`component: web`.

**Benefit**: Keeps `kustomization.yaml` clean; `label-patch.yaml` can grow with more operations.

### 3. ➕ Add a Key (Inline)
**Goal**: Add `org: kodekloud` to `metadata.labels`.

**kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
patches:
  - target:
      kind: Deployment
      name: api-deployment
    patch: |-
      - op: add
        path: /metadata/labels/org
        value: kodekloud
```

**Output (Abridged)**:
```yaml
metadata:
  name: api-deployment
  labels:
    component: api
    org: kodekloud
```

**Technical Breakdown**:
- **op: add**: Inserts a new key-value pair.
- **path: /metadata/labels/org**: Targets the `org` key in `labels`—if it doesn’t exist, it’s created.
- **value: kodekloud**: The value to add.

### 4. ➖ Remove a Key (Inline)
**Starting Point**: Assume `labels` now has `component: api` and `org: kodekloud`.

**Goal**: Remove `org: kodekloud`.

**kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
patches:
  - target:
      kind: Deployment
      name: api-deployment
    patch: |-
      - op: remove
        path: /metadata/labels/org
```

**Output (Abridged)**:
```yaml
metadata:
  name: api-deployment
  labels:
    component: api
```

**Technical Breakdown**:
- **op: remove**: Deletes the specified key.
- **path: /metadata/labels/org**: Targets the `org` key for removal—no `value` needed.

---

## 🔧 Strategic Merge Patch: Inline and Separate File Examples

### 1. 🔖 Replace a Key (Inline)
**Goal**: Change `component: api` to `component: web`.

**kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
patchesStrategicMerge:
  - |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: api-deployment
      labels:
        component: web
```

**Output**: Same as JSON 6902—`component: web`.

### 2. 🔖 Replace a Key (Separate File)
**kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
patchesStrategicMerge:
  - label-patch.yaml
```

**label-patch.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deployment
  labels:
    component: web
```

**Output**: Same as inline—`component: web`.

**Technical Breakdown**:
- **Structure**: Mirrors the base YAML, specifying only changed fields.
- **Merge**: Kustomize merges this with `deployment.yaml`, updating `component` while preserving other keys (e.g., Pod `labels`).

### 3. ➕ Add a Key (Separate File)
**Goal**: Add `org: kodekloud`.

**kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
patchesStrategicMerge:
  - label-patch.yaml
```

**label-patch.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deployment
  labels:
    org: kodekloud
```

**Output (Abridged)**:
```yaml
metadata:
  name: api-deployment
  labels:
    component: api
    org: kodekloud
```

**Technical Breakdown**:
- **Merge Logic**: Adds `org: kodekloud` to `labels` without overwriting `component: api`—Strategic Merge preserves existing keys.

### 4. ➖ Remove a Key (Separate File)
**Starting Point**: `labels: { component: api, org: kodekloud }`.

**Goal**: Remove `org: kodekloud`.

**kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
patchesStrategicMerge:
  - label-patch.yaml
```

**label-patch.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deployment
  labels:
    org: null
```

**Output (Abridged)**:
```yaml
metadata:
  name: api-deployment
  labels:
    component: api
```

**Technical Breakdown**:
- **Null Trick**: Setting `org: null` signals Kustomize to remove that key during the merge.
- **Contrast**: Unlike JSON 6902’s explicit `remove`, Strategic Merge uses this implicit nulling approach.

---

## 🔄 Applying Patches
**Commands**:
- **With Pipe**:
  ```bash
  kustomize build k8s/ | kubectl apply -f -
  ```
- **Native `kubectl`**:
  ```bash
  kubectl apply -k k8s/
  ```

**Verification**:
```bash
kubectl get deployment api-deployment -o jsonpath='{.metadata.labels}'
# Example output: {"component":"web"}
```

---

## ✅ Inline vs. Separate File: Pros and Cons
| Aspect             | 🔍 Inline                     | 🌈 Separate File             |
|--------------------|-------------------------------|-----------------------------|
| **Readability**    | Clutters with many patches   | Keeps `kustomization.yaml` clean |
| **Maintenance**    | All in one file              | Modular, reusable files     |
| **Use Case**       | Quick, small changes         | Complex, multi-patch setups |

**Real-World Example**: Inline for a single replica tweak; separate files for a 10-patch overhaul across microservices.

---

## 🎯 Conclusion: Mastering Patch Flexibility
Kustomize patches—whether JSON 6902 or Strategic Merge—offer precise, scalable customization. Inline patches keep things simple, while separate files declutter complex setups. We’ve seen how to replace (`component: api` to `web`), add (`org: kodekloud`), and remove (`org`) dictionary keys, using both patch types. JSON 6902 provides surgical precision with `op`, `path`, and `value`, while Strategic Merge leverages familiar YAML for intuitive merges.

**Key Takeaways**:
- **Inline vs. File**: Choose based on complexity—both work seamlessly.
- **Dictionary Ops**: Replace, add, or remove keys with ease.
- **Power Combo**: Mix patch types and methods for ultimate control.


---

