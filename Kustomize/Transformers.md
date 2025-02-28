
# 🚀 Transforming Kubernetes Configs with Kustomize: Mastering Common Transformers

## 📖 Introduction: The Power of Transformers
Kustomize isn’t just about aggregating resources—it’s a powerful tool for modifying and transforming Kubernetes manifests. This is achieved through **Kustomize Transformers**, built-in utilities that apply consistent changes across your resources. While Kustomize supports custom transformers, this section focuses on a subgroup called **Common Transformers**, which address frequent configuration needs. Before diving into their specifics, let’s explore the problem they solve and how they streamline Kubernetes management.

---

## ⚠️ The Problem: Repetitive Manual Changes
Consider a simple setup with two Kubernetes manifests:

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

**Scenario**: You want to apply consistent changes across both files:
- Add a label like `org: kodekloud` to all resources.
- Append a suffix like `-dev` to all resource names (e.g., `app-dev`, `app-svc-dev`).
- Place everything in a namespace (e.g., `development`).

**Manual Approach**:
- Edit `deployment.yaml` to add `labels: { org: kodekloud }` under `metadata` and `spec.template.metadata`, and change `name: app` to `name: app-dev`.
- Edit `service.yaml` to add `labels: { org: kodekloud }` and update `name: app-svc` to `name: app-svc-dev`.
- Add `namespace: development` to both.

**Real-World Context**: With just two files, this is doable. But in production, you might have 20, 50, or 100 YAML files—Deployments, Services, ConfigMaps, and more. Manually editing each one is:
- **Time-Consuming**: Hours spent on repetitive updates.
- **Error-Prone**: Miss a file, and you’ve got inconsistent configs (e.g., `app-svc` lacks the suffix).
- **Unscalable**: Adding a new resource means more manual edits.

**Solution**: Kustomize’s Common Transformers automate these changes across all resources, saving time and ensuring consistency.

---

## 🌟 What Are Common Transformers?
Common Transformers are built-in Kustomize utilities that apply uniform modifications to all resources listed in a `kustomization.yaml` file. They’re ideal for tasks like adding labels, adjusting names, setting namespaces, or attaching annotations—changes you want everywhere without touching individual files.

**Key Transformers**:
1. **CommonLabels**: Adds labels to all resources.
2. **NamePrefix/NameSuffix**: Prepends or appends strings to resource names.
3. **Namespace**: Assigns a namespace to all resources.
4. **CommonAnnotations**: Adds annotations to all resources.

---

## 🛠️ Common Transformers in Action
Let’s apply these transformers to our `k8s/` directory using a `kustomization.yaml` file. We’ll build it incrementally to demonstrate each one.

### 1. 🔖 CommonLabels Transformer
**Purpose**: Adds a specified label to the `metadata.labels` of all resources (and Pod templates in Deployments).

**Example**:
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
- **Scope**: Applies to `metadata.labels` of all resources and `spec.template.metadata.labels` in Deployments (for Pods).
- **Use Case**: Tag resources for ownership (e.g., `org: kodekloud`), filtering (`kubectl get pods -l org=kodekloud`), or compliance.
- **Real-World Example**: A team adds `team: frontend` to track resources by department.

### 2. 🌍 Namespace Transformer
**Purpose**: Places all resources under a specified Kubernetes namespace.

**Example**:
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
- **Scope**: Adds `metadata.namespace` to all resources. Doesn’t override existing namespaces unless explicitly patched.
- **Selector Adjustment**: Updates `spec.selector` in Services to include the namespace implicitly (via Kubernetes scoping rules).
- **Use Case**: Isolate environments (e.g., `development`, `production`) or tenants in a shared cluster.
- **Real-World Example**: A CI pipeline uses `namespace: ci-$BUILD_ID` for isolated test runs.

### 3. 🔤 NamePrefix and NameSuffix Transformers
**Purpose**: Prepends or appends strings to the `metadata.name` of all resources.

**Example**:
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
- **Scope**: Modifies `metadata.name` only—selectors and labels remain unchanged unless patched separately.
- **NamePrefix**: Add `namePrefix: my-` to get `my-app-dev`, `my-app-svc-dev`.
- **Use Case**: Differentiate environments (e.g., `-dev`, `-prod`) or instances (e.g., `user1-`).
- **Real-World Example**: A multi-tenant app prepends tenant IDs (e.g., `tenant1-app`) to avoid name collisions.

**Gotcha**: If selectors need updating (e.g., `app-dev` instead of `app`), use a patch:
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

### 4. 📝 CommonAnnotations Transformer
**Purpose**: Adds annotations to the `metadata.annotations` of all resources.

**Example**:
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
- **Scope**: Adds to `metadata.annotations`, not Pod templates (use patches for Pod-level annotations).
- **Use Case**: Add metadata like `owner: dev-team`, `deployed-by: ci`, or `description: testing-env`.
- **Real-World Example**: An ops team annotates resources with `last-updated: 2025-02-28` for auditing.

---

## 🔄 Applying the Transformations
**Command**:
```bash
kubectl apply -k k8s/
# OR
kustomize build k8s/ | kubectl apply -f -
```

**Result**: Deploys `app-dev` (Deployment) and `app-svc-dev` (Service) in the `development` namespace, both with `org: kodekloud` labels and `purpose: development-testing` annotations.

**Debugging Tip**: Run `kustomize build k8s/` to preview the output before applying.

---

## ✅ Why Common Transformers Matter
| Transformer         | Problem Solved                          | Benefit                              |
|---------------------|-----------------------------------------|--------------------------------------|
| `commonLabels`      | Manual label addition                  | Uniform tagging across resources    |
| `namespace`         | Namespace scattering                   | Centralized environment scoping     |
| `namePrefix/suffix` | Name collisions or env distinction     | Consistent naming conventions       |
| `commonAnnotations` | Metadata repetition                    | Streamlined metadata management     |

**Scalability**: With 100 files, editing each manually is a nightmare. Transformers apply changes in one place, instantly affecting everything.

---

## 🎯 Conclusion: Transforming with Ease
Kustomize’s Common Transformers—`commonLabels`, `namespace`, `namePrefix/suffix`, and `commonAnnotations`—offer a declarative way to enforce consistency across Kubernetes resources. In our example, we transformed a basic Deployment and Service with labels, a namespace, a suffix, and annotations, all without altering the original YAML files. This scalability and simplicity make Kustomize invaluable for production-grade Kubernetes management.

**Key Takeaways**:
- **Automation**: Avoid manual edits with centralized transformations.
- **Flexibility**: Apply common configs to any number of resources.
- **Power**: Even basic transformers unlock significant customization.

**Next Steps**:
- Experiment with these transformers in a local cluster.
- Combine with patches for granular tweaks (e.g., selector updates).
- Explore advanced transformers like `images` or `patchesJson6902` for deeper modifications.

---

