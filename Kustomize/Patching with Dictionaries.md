# 🚀 Kustomize Deep Notes: Updating Dictionaries in Kubernetes Configs

---

## 📖 Overview: Precision Patching with Kustomize
Kustomize patches allow you to modify Kubernetes resources (e.g., Deployments, Services) with surgical precision, updating dictionaries like `labels` or `annotations`. This guide covers **JSON 6902** and **Strategic Merge** patches, focusing on three operations: **update**, **add**, and **remove**. With clear examples, a full directory structure, and practical tips, you’ll master patching for scalable Kubernetes management.

**Why Patch?**
- **JSON 6902**: Precise, operation-based changes (e.g., replace a specific label).
- **Strategic Merge**: Intuitive, YAML-like updates for broader changes.
- **Use Case**: Add `org: kodekloud`, update `component: api` to `component: web`, or remove unwanted labels without editing base YAMLs.

**Status**: As of April 26, 2025, both patch types are fully supported in Kustomize (Kubernetes 1.29+). No deprecated concepts.

---

## 🗂️ Example Setup
Let’s start with a base Deployment to demonstrate patching:

**Directory Structure**:
```
k8s/
├── base/
│   ├── api-deployment.yaml
│   ├── kustomization.yaml
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   ├── patches/
│   │   │   ├── label-patch.yaml
```

- **base/api-deployment.yaml**:
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
          component: api
      spec:
        containers:
        - name: api
          image: my-api:latest
  ```

- **base/kustomization.yaml**:
  ```yaml
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - api-deployment.yaml
  ```

We’ll apply patches in the `dev` overlay to modify labels in `api-deployment`.

---

## 🔍 1. JSON 6902 Patch
**Purpose**: Modify resources using precise, operation-based changes defined by RFC 6902. Ideal for pinpoint edits like updating a single label.

**Syntax**:
- `op`: Operation (`replace`, `add`, `remove`).
- `path`: JSON Pointer to the target field (e.g., `/spec/template/metadata/labels/component`).
- `value`: New value (for `add` or `replace`).

### ✏️ (a) Update a Key (Label)
**Goal**: Change `component: api` to `component: web` in Pod template labels.

**overlays/dev/kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
patches:
  - target:
      group: apps
      version: v1
      kind: Deployment
      name: api-deployment
    patch: |-
      - op: replace
        path: /spec/template/metadata/labels/component
        value: web
```

**Output (Abridged)**:
```yaml
spec:
  template:
    metadata:
      labels:
        app: api
        component: web
```

**Key Points**:
- **Operation**: `replace` updates an existing key.
- **Path**: `/spec/template/metadata/labels/component` navigates to the `component` label.
- **Value**: `web` replaces `api`.
- **Gotcha**: Incorrect paths (e.g., `/labels/component`) fail silently. Use `kustomize build` to debug.

### ➕ (b) Add a New Key (Label)
**Goal**: Add `org: kodekloud` to Pod template labels.

**overlays/dev/kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
patches:
  - target:
      group: apps
      version: v1
      kind: Deployment
      name: api-deployment
    patch: |-
      - op: add
        path: /spec/template/metadata/labels/org
        value: kodekloud
```

**Output (Abridged)**:
```yaml
spec:
  template:
    metadata:
      labels:
        app: api
        component: api
        org: kodekloud
```

**Key Points**:
- **Operation**: `add` inserts a new key-value pair.
- **Path**: Targets the `labels` dictionary; `org` is the new key.
- **Edge Case**: If `labels` doesn’t exist, use `/spec/template/metadata/labels` with a full `value` object (e.g., `{ org: kodekloud }`).

### ❌ (c) Remove a Key (Label)
**Goal**: Remove `component: api` from Pod template labels.

**overlays/dev/kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
patches:
  - target:
      group: apps
      version: v1
      kind: Deployment
      name: api-deployment
    patch: |-
      - op: remove
        path: /spec/template/metadata/labels/component
```

**Output (Abridged)**:
```yaml
spec:
  template:
    metadata:
      labels:
        app: api
```

**Key Points**:
- **Operation**: `remove` deletes the specified key.
- **Path**: Points to the exact key (`component`).
- **Gotcha**: If the path doesn’t exist, the operation is ignored (no error).

---

## 🌍 2. Strategic Merge Patch
**Purpose**: Update resources using Kubernetes-native YAML, merging changes into the base config. Ideal for intuitive, broader updates.

**Syntax**:
- Provide a partial resource YAML with only the fields to change.
- Kustomize merges it with the base, preserving unlisted fields.
- Use `null` to remove fields.

### ✏️ (a) Update a Key (Label)
**Goal**: Change `component: api` to `component: web` in Pod template labels.

**overlays/dev/patches/label-patch.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deployment
spec:
  template:
    metadata:
      labels:
        component: web
```

**overlays/dev/kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
patchesStrategicMerge:
  - patches/label-patch.yaml
```

**Output (Abridged)**:
```yaml
spec:
  template:
    metadata:
      labels:
        app: api
        component: web
```

**Key Points**:
- **Merge**: Updates `component` while preserving `app`.
- **Structure**: Matches the base resource’s hierarchy.
- **Gotcha**: Ensure `metadata.name` and `kind` match the target resource.

### ➕ (b) Add a New Key (Label)
**Goal**: Add `org: kodekloud` to Pod template labels.

**overlays/dev/patches/label-patch.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deployment
spec:
  template:
    metadata:
      labels:
        org: kodekloud
```

**overlays/dev/kustomization.yaml** (same as above):
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
patchesStrategicMerge:
  - patches/label-patch.yaml
```

**Output (Abridged)**:
```yaml
spec:
  template:
    metadata:
      labels:
        app: api
        component: api
        org: kodekloud
```

**Key Points**:
- **Merge**: Adds `org` to existing labels.
- **Simplicity**: No need to specify operations or paths.
- **Edge Case**: If `labels` doesn’t exist, it’s created automatically.

### ❌ (c) Remove a Key (Label)
**Goal**: Remove `component: api` from Pod template labels.

**overlays/dev/patches/label-patch.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deployment
spec:
  template:
    metadata:
      labels:
        component: null
```

**overlays/dev/kustomization.yaml** (same as above):
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
patchesStrategicMerge:
  - patches/label-patch.yaml
```

**Output (Abridged)**:
```yaml
spec:
  template:
    metadata:
      labels:
        app: api
```

**Key Points**:
- **Removal**: Setting `component: null` removes the key.
- **Gotcha**: Incorrect keys (e.g., `comp: null`) are ignored; ensure exact match.

---

## 📊 Summary Table
| Operation | JSON 6902 Patch | Strategic Merge Patch |
|:----------|:----------------|:---------------------|
| **Update** | `op: replace`, specify `path` and `value` | Overwrite value in YAML |
| **Add** | `op: add`, specify `path` and `value` | Add key-value in YAML |
| **Remove** | `op: remove`, specify `path` | Set key to `null` |

---

## 🔧 Applying and Verifying Patches
**Directory**:
```
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
kubectl get deployment api-deployment -o jsonpath='{.spec.template.metadata.labels}' -n default
# Example Output: map[app:api component:web org:kodekloud]
```

**Debugging Tips**:
- **JSON 6902**: Check `path` syntax (e.g., `/spec` not `/spec/`).
- **Strategic Merge**: Ensure `metadata.name` matches the base resource.
- **Preview**: Use `kustomize build` to catch errors before applying.

---

## 💡 Important Tips
- **JSON 6902**:
  - Use for **precise, programmatic** changes (e.g., CI scripts).
  - Validate paths with tools like `yq` or `kustomize build`.
  - Example: `/spec/template/metadata/labels` for Pod labels, not `/metadata/labels` (Deployment-level).
- **Strategic Merge**:
  - Use for **readable, YAML-like** updates.
  - Ideal for larger changes (e.g., multiple labels or resources).
  - Keep patch files minimal to avoid unintended overwrites.
- **Organization**:
  - Store patches in a `patches/` directory for clarity.
  - Use overlays (e.g., `dev`, `prod`) for environment-specific changes.
- **Edge Cases**:
  - **Selector Mismatch**: If labels affect selectors, patch `spec.selector.matchLabels` (e.g., `app: api` to `app: api-dev`).
  - **Non-Existent Paths**: JSON 6902 fails silently; Strategic Merge creates missing fields.
  - **Multiple Patches**: Order matters in JSON 6902 (e.g., `add` before `replace`).

---

## 🌟 Advanced Use Cases
1. **Dynamic Labels in CI/CD**:
   ```yaml
   patches:
     - target:
         kind: Deployment
         name: api-deployment
       patch: |-
         - op: add
           path: /spec/template/metadata/labels/build-id
           value: "${BUILD_ID}"
   ```
   **Use Case**: Add build metadata for traceability.

2. **Label-Based Targeting**:
   ```yaml
   patches:
     - target:
         kind: Deployment
         labelSelector: app=api
       patch: |-
         - op: add
           path: /spec/template/metadata/labels/env
           value: dev
   ```
   **Use Case**: Apply labels to all resources with `app: api`.

3. **Multi-Label Updates**:
   **label-patch.yaml**:
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: api-deployment
   spec:
     template:
       metadata:
         labels:
           env: dev
           region: us-east
   ```
   **Use Case**: Update multiple labels in one patch.

---

## 🎯 Conclusion
Kustomize patches—JSON 6902 and Strategic Merge—offer powerful ways to update dictionaries like `labels` in Kubernetes configs. JSON 6902 provides precise, operation-based control, while Strategic Merge offers intuitive, YAML-native updates. With the provided directory structure, examples, and tips, you can confidently apply **update**, **add**, and **remove** operations for scalable, environment-specific customization.

**Key Takeaways**:
- **JSON 6902**: Pinpoint changes with `replace`, `add`, `remove`.
- **Strategic Merge**: Simple, readable updates with YAML.
- **Scalability**: Use overlays and patches for complex setups.


