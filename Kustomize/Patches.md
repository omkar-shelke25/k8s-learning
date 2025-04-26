
# 🚀 Precision Customization with Kustomize: Exploring Patches (Enhanced)

## 📖 Introduction: Patches for Targeted Changes
Kustomize patches provide a **surgical** approach to modifying Kubernetes configurations, enabling precise tweaks to specific resources or fields without altering base YAML files. Unlike **Common Transformers** (e.g., `commonLabels`, `namespace`), which apply uniform changes across all resources, patches target individual objects or attributes—ideal for tasks like adjusting `replicas` or renaming a single Deployment. This enhanced guide explores patch mechanics, compares **JSON 6902** and **Strategic Merge** patches, and dives into advanced scenarios for maximum control.

**Note**: As of April 26, 2025, Kustomize patches are fully supported in Kubernetes 1.29+ and standalone Kustomize. No concepts have been deprecated or redefined.

---

## 🌟 Patches vs. Common Transformers
| Aspect                | Common Transformers                  | Patches                           |
|-----------------------|--------------------------------------|-----------------------------------|
| **Scope**             | Broad, applies to all resources      | Targeted, specific resources/fields |
| **Use Case**          | Uniform changes (e.g., add labels)   | Granular tweaks (e.g., change replicas) |
| **Analogy**           | Painting the entire house one color  | Repainting just the front door    |

**Real-World Example**: Use transformers to add `env: prod` to all resources; use patches to increase `replicas` only for a `frontend-deployment`.

---

## 🛠️ Anatomy of a Patch
A Kustomize patch requires three core components (except for `remove` operations):
1. **Operation Type**: The action to perform (`add`, `remove`, `replace`).
2. **Target**: The resource(s) to modify, based on match criteria.
3. **Value**: The data to apply (for `add` or `replace`).

### 1. 🔧 Operation Types
Common operations include:
- **Add**: Inserts a new element (e.g., add an `env` variable to a container).
- **Remove**: Deletes an element (e.g., remove a label).
- **Replace**: Updates an existing value (e.g., change `replicas: 1` to `replicas: 5`).

**Rare Operations**: JSON 6902 supports `test` (validate a value) and `move` (relocate a field), but these are uncommon in Kustomize.

**Examples**:
- **Add**: Append a sidecar container.
- **Remove**: Delete an unused annotation.
- **Replace**: Update `image` to a new version.

### 2. 🔍 Target
Specifies which resource(s) to patch using criteria:
- `kind`: Resource type (e.g., `Deployment`, `Service`).
- `name`: Resource name (e.g., `api-deployment`).
- `namespace`: Namespace (if applicable).
- `group`/`version`: API group/version (e.g., `apps/v1`).
- `labelSelector`: Match by labels (e.g., `app=frontend`).
- `annotationSelector`: Match by annotations.

**Precision**: Combine criteria for specificity (e.g., `kind: Deployment`, `name: api-deployment`, `namespace: dev`).

### 3. 📝 Value
The data to apply:
- **Add**: New element (e.g., a container spec).
- **Replace**: New value (e.g., `5` for `replicas`).
- **Remove**: Not needed.

**Real-World Context**: Patch `frontend-deployment` to add CPU limits, leaving `backend-deployment` unchanged.

---

## 🌍 Patches in Action: JSON 6902 Patch
Let’s apply JSON 6902 patches to a sample Deployment.

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
- **Target**: Matches `kind: Deployment`, `name: api-deployment`.
- **Patch**:
  - `op: replace`: Updates the field.
  - `path: /metadata/name`: JSON Pointer to `metadata.name` (root → `metadata` → `name`).
  - `value: web-deployment`: New value.
- **Syntax**: The `|-` indicates a multi-line YAML string for JSON 6902 patches.

**Gotcha**: Changing `metadata.name` may require updating `spec.selector.matchLabels` or `template.metadata.labels` to avoid Pod-selector mismatches.

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
- **Path**: `/spec/replicas` targets `spec.replicas`.
- **Value**: `5` replaces `1`.
- **Precision**: Only `replicas` is modified.

**Deep Dive**:
- **JSON Pointer**: Uses RFC 6902 syntax (`/` for hierarchy, `0` for array indices, e.g., `/spec/template/spec/containers/0/image` for the first container’s image).
- **RFC 6902**: Defines `add`, `remove`, `replace`, etc. See [RFC 6902](https://tools.ietf.org/html/rfc6902).

#### Example 3: Add an Environment Variable
**Goal**: Add `ENV=prod` to the `api` container.

**kustomization.yaml**:
```yaml
patches:
  - target:
      kind: Deployment
      name: api-deployment
    patch: |-
      - op: add
        path: /spec/template/spec/containers/0/env
        value:
          - name: ENV
            value: prod
```

**Output (Abridged)**:
```yaml
spec:
  template:
    spec:
      containers:
      - name: api
        image: my-api:latest
        env:
        - name: ENV
          value: prod
```

**Note**: If `env` doesn’t exist, `add` creates it. If it exists, `add` appends to the list.

---

## 🔧 Alternative: Strategic Merge Patch
Strategic Merge Patches use Kubernetes-native YAML, making them more intuitive.

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
- **Structure**: Mimics a partial Deployment YAML, specifying only changes.
- **Target**: Matches via `metadata.name`, `kind`, and `apiVersion`.
- **Merge**: Updates `replicas` while preserving other fields.
- **Strategic**: Understands Kubernetes list semantics (e.g., `containers` are merged by `name`, not overwritten).

**Example: Add Resources**:
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
              requests:
                cpu: "200m"
```

**Output (Abridged)**:
```yaml
spec:
  template:
    spec:
      containers:
      - name: api
        image: my-api:latest
        resources:
          limits:
            cpu: "500m"
          requests:
            cpu: "200m"
```

**Note**: The `api` container is matched by `name`, and `resources` is added or updated.

---

## 🔄 Applying Patches
**Commands**:
- **Preview**:
  ```bash
  kustomize build k8s/
  ```
- **Apply with Pipe**:
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

**Debugging Tip**: Use `kustomize build` to inspect output. Check `target` criteria or `path` syntax if patches don’t apply.

---

## ✅ JSON 6902 vs. Strategic Merge: Enhanced Comparison
| Aspect                | 🔍 JSON 6902 Patch              | 🌈 Strategic Merge Patch       |
|-----------------------|---------------------------------|--------------------------------|
| **Syntax**            | Operation-based (`op`, `path`) | Kubernetes YAML-like          |
| **Readability**       | Technical, JSON Pointer-based  | Intuitive, YAML-native        |
| **Precision**         | Pinpoint (any field)           | Broad (merges structures)     |
| **Use Case**          | Low-level, programmatic edits  | Natural Kubernetes tweaks     |
| **Lists**             | Manual index (e.g., `/0`)      | Matches by `name` (e.g., containers) |
| **Learning Curve**    | Steeper (RFC 6902)             | Easier (YAML knowledge)       |

**When to Choose**:
- **JSON 6902**: Ideal for precise changes (e.g., modifying a specific array index) or CI-driven patches.
- **Strategic Merge**: Preferred for readability and Kubernetes-native edits (e.g., adding resources or replicas).

**Mixing**:
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

## 🚀 Advanced Use Cases
1. **Remove an Annotation** (JSON 6902):
   ```yaml
   patches:
     - target:
         kind: Deployment
         name: api-deployment
       patch: |-
         - op: remove
           path: /metadata/annotations/deprecated
   ```
   **Use Case**: Clean up outdated annotations.

2. **Add a Sidecar Container** (Strategic Merge):
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
             - name: sidecar
               image: envoyproxy/envoy:v1.20.0
   ```
   **Use Case**: Inject a proxy without modifying the base.

3. **Label-Based Targeting** (JSON 6902):
   ```yaml
   patches:
     - target:
         kind: Deployment
         labelSelector: app=api
       patch: |-
         - op: replace
           path: /spec/replicas
           value: 3
   ```
   **Use Case**: Update all Deployments with `app=api`, regardless of name.

4. **Overlay-Specific Patches**:
   ```
   k8s/
   ├── base/
   │   ├── deployment.yaml
   │   ├── kustomization.yaml
   ├── overlays/
   │   ├── prod/
   │   │   ├── kustomization.yaml
   │   ├── dev/
   │   │   ├── kustomization.yaml
   ```
   - **overlays/prod/kustomization.yaml**:
     ```yaml
     bases:
       - ../../base
     patchesStrategicMerge:
       - |-
         apiVersion: apps/v1
         kind: Deployment
         metadata:
           name: api-deployment
         spec:
           replicas: 5
     ```
   - **overlays/dev/kustomization.yaml**:
     ```yaml
     bases:
       - ../../base
     patches:
       - target:
           kind: Deployment
           name: api-deployment
         patch: |-
           - op: add
             path: /spec/template/spec/containers/0/env
             value:
               - name: DEBUG
                 value: "true"
     ```
   **Use Case**: Scale to 5 replicas in production; add debug env in dev.

---

## 🎯 Conclusion: Patches for Precision
Kustomize patches—JSON 6902 and Strategic Merge—offer unparalleled precision for Kubernetes configuration. JSON 6902 excels at low-level, field-specific edits, while Strategic Merge provides a YAML-native, intuitive approach. In our examples, we renamed a Deployment, scaled replicas, and added environment variables, demonstrating their power. Combined with transformers, patches enable layered, environment-specific customization without touching base configs.

**Key Takeaways**:
- **Granular Control**: Target specific fields or resources.
- **Dual Approaches**: JSON 6902 for precision, Strategic Merge for ease.
- **Scalability**: Apply targeted changes across complex setups.

**Next Steps**:
- Test `remove` operations to delete fields.
- Combine patches with Image Transformers for full customization.
- Explore `labelSelector` for dynamic targeting.

**No Deprecation Note**: Kustomize patches (JSON 6902 and Strategic Merge) are fully supported in Kubernetes 1.29+ and standalone Kustomize. No concepts have been deprecated or redefined.

---

This enhanced guide clarifies syntax, adds advanced use cases (e.g., sidecars, label-based targeting), and confirms the absence of deprecated concepts. Let me know if you need further refinements, additional examples, or assistance with testing these patches!
