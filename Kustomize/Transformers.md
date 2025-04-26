

# 🚀 Transforming Kubernetes Configs with Kustomize: Mastering Common Transformers (Enhanced)

## 📖 Introduction: The Power of Transformers
Kustomize is more than a resource aggregator—it’s a robust tool for transforming Kubernetes manifests declaratively. At its core are **Kustomize Transformers**, utilities that apply consistent modifications across resources. This guide focuses on **Common Transformers**, a subset designed for frequent configuration tasks like adding labels, setting namespaces, or renaming resources. We’ll explore their mechanics, solve real-world problems, and demonstrate their scalability for production-grade Kubernetes management.

**Note**: As of April 26, 2025, Common Transformers are fully supported in Kubernetes 1.29+ and standalone Kustomize. No concepts have been deprecated or redefined.

---

## ⚠️ The Problem: Repetitive Manual Changes
Consider a simple setup:

```
k8s/
├── deployment.yaml
├── service.yaml
```

- **deployment.yaml**:
  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: app
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: frontend
    template:
      metadata:
        labels:
          app: frontend
      spec:
        containers:
        - name: app
          image: my-app:latest
  ```

- **service.yaml**:
  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: app-svc
  spec:
    selector:
      app: frontend
    ports:
    - port: 80
  ```

**Scenario**: You need to:
- Add `org: kodekloud` to all resources.
- Append `-dev` to resource names (e.g., `app-dev`, `app-svc-dev`).
- Place resources in the `development` namespace.

**Manual Approach**:
- Edit `deployment.yaml`: Add `labels: { org: kodekloud }` to `metadata` and `spec.template.metadata`, change `name: app` to `name: app-dev`, add `namespace: development`.
- Edit `service.yaml`: Add `labels: { org: kodekloud }`, change `name: app-svc` to `name: app-svc-dev`, add `namespace: development`.

**Challenges**:
- **Time-Consuming**: Editing multiple files is tedious.
- **Error-Prone**: Miss a label or namespace, and configs become inconsistent.
- **Unscalable**: With 50+ YAML files (Deployments, Services, ConfigMaps), manual edits are impractical.

**Solution**: Kustomize’s Common Transformers automate these changes via a single `kustomization.yaml`, ensuring consistency and scalability.

---

## 🌟 What Are Common Transformers?
Common Transformers are built-in Kustomize utilities that apply uniform modifications to all resources listed in `kustomization.yaml`. They’re perfect for tasks requiring consistency, such as adding labels, setting namespaces, or renaming resources.

**Key Transformers**:
1. **CommonLabels**: Adds labels to all resources and Pod templates.
2. **NamePrefix/NameSuffix**: Prepends or appends strings to resource names.
3. **Namespace**: Assigns a namespace to all resources.
4. **CommonAnnotations**: Adds annotations to all resources.

**Scope**: Apply to all resources under `resources`, unlike patches, which target specific objects.

---

## 🛠️ Common Transformers in Action
Let’s transform our `k8s/` directory using `kustomization.yaml`, building incrementally to showcase each transformer.

### 1. 🔖 CommonLabels Transformer
**Purpose**: Adds labels to `metadata.labels` of all resources and `spec.template.metadata.labels` in Deployments/StatefulSets.

**kustomization.yaml**:
```yaml
# k8s/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
commonLabels:
  org: kodekloud
```

**Command**:
```bash
kustomize build k8s/
```

**Output (Abridged)**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-svc
  labels:
    org: kodekloud
spec:
  selector:
    app: frontend
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  labels:
    org: kodekloud
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        org: kodekloud
    spec:
      containers:
      - name: app
        image: my-app:latest
```

**Technical Breakdown**:
- **Scope**: Adds `org: kodekloud` to `metadata.labels` (all resources) and `spec.template.metadata.labels` (Pod templates).
- **Behavior**: Merges with existing labels; doesn’t overwrite unless keys conflict.
- **Use Case**: Tag resources for ownership (`org: kodekloud`), filtering (`kubectl get pods -l org=kodekloud`), or compliance.
- **Real-World Example**: Add `team: frontend` to track resources by department.

**Edge Case**: Labels on Pod templates ensure Pods inherit them, but selectors (`spec.selector.matchLabels`) remain unchanged unless patched.

### 2. 🌍 Namespace Transformer
**Purpose**: Places all resources in a specified namespace.

**kustomization.yaml**:
```yaml
# k8s/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
namespace: development
commonLabels:
  org: kodekloud
```

**Output (Abridged)**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-svc
  namespace: development
  labels:
    org: kodekloud
spec:
  selector:
    app: frontend
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: development
  labels:
    org: kodekloud
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        org: kodekloud
    spec:
      containers:
      - name: app
        image: my-app:latest
```

**Technical Breakdown**:
- **Scope**: Adds `metadata.namespace: development` to all resources.
- **Behavior**: Overrides existing `metadata.namespace` if present.
- **Selectors**: Kubernetes scopes Service selectors to the namespace automatically.
- **Use Case**: Isolate environments (`development`, `production`) or tenants.
- **Real-World Example**: Use `namespace: ci-$BUILD_ID` for isolated CI runs.

**Edge Case**: Namespace transformer doesn’t affect cluster-scoped resources (e.g., `ClusterRole`). Use patches for those.

### 3. 🔤 NamePrefix and NameSuffix Transformers
**Purpose**: Prepends or appends strings to `metadata.name` of all resources.

**kustomization.yaml**:
```yaml
# k8s/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
namespace: development
commonLabels:
  org: kodekloud
nameSuffix: -dev
```

**Output (Abridged)**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-svc-dev
  namespace: development
  labels:
    org: kodekloud
spec:
  selector:
    app: frontend
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-dev
  namespace: development
  labels:
    org: kodekloud
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        org: kodekloud
    spec:
      containers:
      - name: app
        image: my-app:latest
```

**Technical Breakdown**:
- **Scope**: Modifies `metadata.name` only.
- **NamePrefix**: Add `namePrefix: my-` for `my-app-dev`, `my-app-svc-dev`.
- **Selectors**: Unchanged, which may break Services if `nameSuffix` alters Deployment names (e.g., Service expects `app` but Deployment is `app-dev`).
- **Use Case**: Differentiate environments (`-dev`, `-prod`) or tenants (`tenant1-`).
- **Real-World Example**: Prevent name collisions in multi-tenant clusters.

**Fixing Selectors** (if needed):
```yaml
patchesStrategicMerge:
  - |-
    apiVersion: v1
    kind: Service
    metadata:
      name: app-svc
    spec:
      selector:
        app: app-dev
```

**Edge Case**: Name changes may conflict with Kubernetes name constraints (e.g., DNS-1123). Ensure suffixes/prefixes produce valid names.

### 4. 📝 CommonAnnotations Transformer
**Purpose**: Adds annotations to `metadata.annotations` of all resources.

**kustomization.yaml**:
```yaml
# k8s/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
namespace: development
commonLabels:
  org: kodekloud
nameSuffix: -dev
commonAnnotations:
  purpose: development-testing
```

**Output (Abridged)**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-svc-dev
  namespace: development
  labels:
    org: kodekloud
  annotations:
    purpose: development-testing
spec:
  selector:
    app: frontend
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-dev
  namespace: development
  labels:
    org: kodekloud
  annotations:
    purpose: development-testing
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        org: kodekloud
    spec:
      containers:
      - name: app
        image: my-app:latest
```

**Technical Breakdown**:
- **Scope**: Adds to `metadata.annotations`, not Pod templates.
- **Behavior**: Merges with existing annotations; doesn’t overwrite unless keys conflict.
- **Use Case**: Add metadata like `owner: dev-team`, `deployed-by: ci`, or `last-updated: 2025-04-26`.
- **Real-World Example**: Annotate resources for auditing or integration with tools like Prometheus (`prometheus.io/scrape: "true"`).

**Edge Case**: To annotate Pod templates, use a Strategic Merge Patch:
```yaml
patchesStrategicMerge:
  - |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: app
    spec:
      template:
        metadata:
          annotations:
            sidecar.istio.io/inject: "true"
```

---

## 🔄 Applying the Transformations
**Commands**:
- **Preview**:
  ```bash
  kustomize build k8s/
  ```
- **Apply**:
  ```bash
  kubectl apply -k k8s/
  # OR
  kustomize build k8s/ | kubectl apply -f -
  ```

**Verification**:
```bash
kubectl get all -n development
# Output: app-dev (Deployment), app-svc-dev (Service)
kubectl get deployment app-dev -n development -o yaml
# Check labels, annotations, namespace
```

**Debugging Tip**: Use `kustomize build k8s/` to inspect output. If resources don’t appear as expected, verify `resources` list or transformer syntax.

---

## ✅ Why Common Transformers Matter
| Transformer         | Problem Solved                          | Benefit                              |
|---------------------|-----------------------------------------|--------------------------------------|
| `commonLabels`      | Manual label addition                  | Uniform tagging for filtering/control |
| `namespace`         | Namespace scattering                   | Centralized environment scoping      |
| `namePrefix/suffix` | Name collisions or env distinction     | Consistent, unique naming            |
| `commonAnnotations` | Metadata repetition                    | Streamlined metadata management      |

**Scalability**: Transformers scale effortlessly to hundreds of resources, eliminating manual edits.

**Consistency**: Ensure all resources align with organizational standards (e.g., labels, namespaces).

---

## 🚀 Advanced Use Cases
1. **Multi-Environment Overlays**:
   ```
   k8s/
   ├── base/
   │   ├── deployment.yaml
   │   ├── service.yaml
   │   ├── kustomization.yaml
   ├── overlays/
   │   ├── prod/
   │   │   ├── kustomization.yaml
   │   ├── dev/
   │   │   ├── kustomization.yaml
   ```
   - **base/kustomization.yaml**:
     ```yaml
     resources:
       - deployment.yaml
       - service.yaml
     commonLabels:
       app: frontend
     ```
   - **overlays/dev/kustomization.yaml**:
     ```yaml
     bases:
       - ../../base
     namespace: development
     nameSuffix: -dev
     commonAnnotations:
       env: dev
     ```
   - **overlays/prod/kustomization.yaml**:
     ```yaml
     bases:
       - ../../base
     namespace: production
     nameSuffix: -prod
     commonAnnotations:
       env: prod
     ```
   **Use Case**: Maintain one base config with environment-specific customizations.

2. **Cluster-Scoped Resources**:
   Handle resources like `ClusterRole` that ignore `namespace`:
   ```yaml
   resources:
     - clusterrole.yaml
   commonLabels:
     org: kodekloud
   patches:
     - target:
         kind: ClusterRole
         name: my-role
       patch: |-
         - op: add
           path: /metadata/annotations
           value:
             purpose: cluster-access
   ```
   **Use Case**: Annotate cluster-scoped resources without namespace conflicts.

3. **Dynamic Labels for CI**:
   ```yaml
   commonLabels:
     build-id: "${BUILD_ID}"
   ```
   **Use Case**: Embed CI pipeline metadata (e.g., Jenkins build ID) for traceability.

4. **Combining with Other Transformers**:
   ```yaml
   resources:
     - deployment.yaml
   commonLabels:
     org: kodekloud
   images:
     - name: my-app
       newTag: 1.2.3
   ```
   **Use Case**: Update image tags alongside labels for a release.

---

## 🎯 Conclusion: Transforming with Ease
Kustomize’s Common Transformers—`commonLabels`, `namespace`, `namePrefix/suffix`, and `commonAnnotations`—provide a declarative, scalable way to customize Kubernetes resources. In our example, we added labels, set a namespace, appended a suffix, and applied annotations to a Deployment and Service, all without modifying base YAMLs. These transformers shine in production, where consistency across dozens or hundreds of resources is critical.

**Key Takeaways**:
- **Automation**: Centralize repetitive changes in `kustomization.yaml`.
- **Scalability**: Apply transformations to any number of resources.
- **Flexibility**: Combine with patches or other transformers for advanced customization.

**Next Steps**:
- Test transformers in a local cluster (e.g., Minikube, Kind).
- Build overlays for multi-environment setups.
- Explore other transformers like `images` or `patchesJson6902`.

**No Deprecation Note**: Common Transformers are fully supported in Kubernetes 1.29+ and standalone Kustomize. No concepts have been deprecated or redefined.

---

