

# 🚀 Precision Customization with Kustomize: Exploring Patches

## 📖 Introduction: Patches for Targeted Changes
Kustomize patches offer a surgical approach to modifying Kubernetes configurations, contrasting with the broad, uniform edits of Common Transformers. While transformers like `commonLabels` or `namespace` apply changes across all resources, patches let you target specific objects or fields—perfect for fine-tuned adjustments like updating replicas or renaming a single Deployment. In this section, we’ll dive into how patches work, explore their key components, and compare the two main patch types: JSON 6902 and Strategic Merge.

---

## 🌟 Patches vs. Common Transformers
**Common Transformers**:
- Apply blanket changes (e.g., add `org: kodekloud` to all resources).
- Great for consistency across everything.

**Patches**:
- Target specific resources or fields (e.g., change `replicas` on one Deployment).
- Ideal for granular, object-specific tweaks.

**Real-World Analogy**: Transformers are like painting an entire house one color; patches are like repainting just the front door.

---

## 🛠️ Anatomy of a Patch
A patch in Kustomize requires three core elements (with one exception for `remove` operations):
1. **Operation Type**: What action to perform (e.g., `add`, `remove`, `replace`).
2. **Target**: Which resource(s) to modify, based on match criteria.
3. **Value**: The new data to apply (for `add` or `replace` operations).

### 1. 🔧 Operation Types
Kustomize supports several operations, but the three most common are:
- **Add**: Inserts a new element (e.g., add a container to a Deployment’s `containers` list).
- **Remove**: Deletes an existing element (e.g., remove a label or container).
- **Replace**: Swaps an existing value with a new one (e.g., change `replicas: 5` to `replicas: 10`).

**Less Common**: Operations like `test` or `move` exist (per JSON 6902 RFC), but they’re niche and rarely used.

**Examples**:
- **Add**: Append a second container to a Deployment.
- **Remove**: Delete an unused `env` variable from a container.
- **Replace**: Update `replicas` from 1 to 5.

### 2. 🔍 Target
Defines which Kubernetes resource(s) to patch using match criteria:
- `kind`: Resource type (e.g., `Deployment`, `Service`).
- `name`: Resource name (e.g., `api-deployment`).
- `namespace`: Namespace (if applicable).
- `version`: API version (e.g., `apps/v1`).
- `labelSelector`: Match by labels (e.g., `app=frontend`).
- `annotationSelector`: Match by annotations.

**Flexibility**: Combine multiple criteria for precision (e.g., `kind: Deployment`, `name: api-deployment`, `namespace: dev`).

### 3. 📝 Value
The data to apply, depending on the operation:
- **Add**: The new element (e.g., a container spec).
- **Replace**: The new value (e.g., `10` for `replicas`).
- **Remove**: Not applicable—no value needed.

**Real-World Context**: In a microservices app, you might patch only the `frontend-deployment` to increase replicas, leaving `backend-deployment` untouched.

---

## 🌍 Patches in Action: JSON 6902 Patch
Let’s apply patches to a sample Deployment using the JSON 6902 format.

### 🗂️ Base Config
```
k8s/
├── deployment.yaml
├── kustomization.yaml
```

- **deployment.yaml**:
  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: api-deployment
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

#### Example 1: Replace the Name
**Goal**: Change `name: api-deployment` to `name: web-deployment`.

**kustomization.yaml**:
```yaml
# k8s/kustomization.yaml
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
        path: /metadata/name
        value: web-deployment
```

**Output (Abridged)**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deployment
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

**Technical Breakdown**:
- **Target**: Matches `kind: Deployment` and `name: api-deployment`.
- **Patch**:
  - `op: replace`: Swaps the existing value.
  - `path: /metadata/name`: Navigates the YAML tree to `metadata.name` (root → `metadata` → `name`).
  - `value: web-deployment`: The new name.
- **Inline Patch**: The `|-` syntax denotes a multi-line YAML string, required for JSON 6902 patches in `kustomization.yaml`.

#### Example 2: Replace Replicas
**Goal**: Change `replicas: 1` to `replicas: 5`.

**kustomization.yaml**:
```yaml
# k8s/kustomization.yaml
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
        path: /spec/replicas
        value: 5
```

**Output (Abridged)**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deployment
spec:
  replicas: 5
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

**Technical Breakdown**:
- **Path**: `/spec/replicas` navigates to `spec.replicas` (root → `spec` → `replicas`).
- **Value**: `5` replaces the original `1`.
- **Precision**: Only `replicas` changes—other fields remain intact.

**Deep Dive**:
- **Path Syntax**: Uses JSON Pointer (RFC 6902), with `/` separating levels. For nested fields (e.g., `containers[0].image`), it’s `/spec/template/spec/containers/0/image`.
- **RFC 6902**: Defines the standard for JSON patches—see [rfc6902](https://tools.ietf.org/html/rfc6902) for full details on operations like `add`, `remove`, and `test`.

---

## 🔧 Alternative: Strategic Merge Patch
The Strategic Merge Patch offers a more Kubernetes-native approach, mimicking regular YAML configs.

### 🗂️ Example: Update Replicas
**kustomization.yaml**:
```yaml
# k8s/kustomization.yaml
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
    spec:
      replicas: 5
```

**Output (Abridged)**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deployment
spec:
  replicas: 5
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

**Technical Breakdown**:
- **Structure**: Looks like a partial Deployment YAML, specifying only what changes.
- **Target**: Implicitly matches via `metadata.name` (and optionally `kind`, `apiVersion`).
- **Merge**: Kustomize merges this with the base config, updating `replicas` from 1 to 5 while preserving other fields.
- **Strategic**: Understands Kubernetes semantics (e.g., lists like `containers` are merged by name, not overwritten).

**How It Works**:
1. Start with the base `deployment.yaml`.
2. Copy the parts you want to change into the patch.
3. Strip out unchanged fields—Kustomize handles the rest.

**Real-World Use**: Adjust `resources.limits` for a specific container:
```yaml
patchesStrategicMerge:
  - |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: api-deployment
    spec:
      template:
        spec:
          containers:
          - name: api
            resources:
              limits:
                cpu: "500m"
```

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
kubectl get deployment api-deployment -o jsonpath='{.spec.replicas}'
# Output: 5
```

---

## ✅ JSON 6902 vs. Strategic Merge: A Comparison
| Aspect                | 🔍 JSON 6902 Patch              | 🌈 Strategic Merge Patch       |
|-----------------------|---------------------------------|--------------------------------|
| **Syntax**            | Operation-based (op, path)     | Kubernetes YAML-like          |
| **Readability**       | Technical, path-driven         | Familiar, intuitive           |
| **Precision**         | Pinpoint (any field)           | Broad (merges structures)     |
| **Use Case**          | Specific, low-level changes    | Natural Kubernetes edits      |
| **Learning Curve**    | Steeper (JSON Pointer)         | Easier (YAML knowledge)       |

**Preference**:
- **JSON 6902**: Great for precise, programmatic changes (e.g., CI scripts).
- **Strategic Merge**: Preferred for readability and Kubernetes-native feel—my go-to for most tasks.

**Mixing**: You can use both in one `kustomization.yaml`:
```yaml
patches:
  - target: { kind: Deployment, name: api-deployment }
    patch: |-
      - op: replace
        path: /metadata/name
        value: web-deployment
patchesStrategicMerge:
  - |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: api-deployment
    spec:
      replicas: 5
```

---

## 🎯 Conclusion: Patches for Precision
Kustomize patches—whether JSON 6902 or Strategic Merge—provide a powerful, targeted way to modify Kubernetes configs. In our examples, we renamed a Deployment and adjusted its replicas, showcasing the flexibility of `op`, `path`, and `value` in JSON 6902, and the simplicity of Strategic Merge’s YAML-like approach. Unlike Common Transformers, patches let you zoom in on specific resources, making them indispensable for fine-grained control.

**Key Takeaways**:
- **Surgical Precision**: Target exact fields or objects.
- **Two Flavors**: JSON 6902 for detail, Strategic Merge for ease.
- **Scalability**: Apply once, affect only what you need.

**Next Steps**:
- Test adding a container with an `add` operation.
- Experiment with `remove` to delete a label.
- Combine patches with transformers for layered customization.

---
