

# 🚀 Getting Started with Kustomize: Mastering the `kustomization.yaml` File

## 📖 Introduction: Diving into Kustomize
Now that Kustomize is installed and configured, it’s time to explore the tool hands-on. The centerpiece of Kustomize is the `kustomization.yaml` file—a configuration file that drives how Kustomize manages and transforms Kubernetes resources. This section focuses on understanding what the `kustomization.yaml` file is, why it’s essential, and how to configure it effectively. Let’s break it down step-by-step with a practical example.

---

## 🛠️ What is the `kustomization.yaml` File?
The `kustomization.yaml` file is Kustomize’s instruction manual. It tells Kustomize which Kubernetes resources to manage and how to customize them. Think of it as a blueprint that orchestrates your manifests and applies transformations, all in a declarative, YAML-based format.

### 🔍 Why Do We Need It?
Kustomize doesn’t blindly process every YAML file in a directory. Instead, it relies on `kustomization.yaml` to:
- **Specify Resources**: Define exactly which manifests (e.g., Deployments, Services) Kustomize should handle.
- **Apply Customizations**: Declare transformations—like adding labels, changing replicas, or patching fields—without altering the original files.
- **Ensure Control**: Provide a single point of configuration, making it explicit and auditable.

**Technical Insight**: Without `kustomization.yaml`, Kustomize has no context—it’s like a chef without a recipe. This file is mandatory and must be named exactly `kustomization.yaml` (or `kustomization.yml`) in the directory you point Kustomize to.

---

## 🗂️ Example Setup: A Simple Kubernetes Directory
Let’s start with a practical example. Imagine a directory called `k8s/` containing two Kubernetes manifests:

```bash
k8s/
├── nginx-deployment.yaml
├── nginx-service.yaml
└── kustomization.yaml  # We’ll create this
```

- **nginx-deployment.yaml**:
  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: nginx-deployment
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: nginx
    template:
      metadata:
        labels:
          app: nginx
      spec:
        containers:
        - name: nginx
          image: nginx:latest
  ```

- **nginx-service.yaml**:
  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: nginx-service
  spec:
    selector:
      app: nginx
    ports:
    - port: 80
      targetPort: 80
  ```

**Context**: These files define a basic NGINX setup—a Deployment with 1 replica and a Service to expose it. Kustomize won’t touch them directly; it needs `kustomization.yaml` to act on them.

---

## 📜 Configuring the `kustomization.yaml` File
You create the `kustomization.yaml` file manually in the `k8s/` directory. It has two core sections: **Resources** and **Transformations**. Let’s configure it for our example.

### 1. 🌟 Resources Section
- **Purpose**: Lists all Kubernetes YAML files Kustomize should manage.
- **Format**: A simple array under the `resources` key.

**Example**:
```yaml
# k8s/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - nginx-deployment.yaml
  - nginx-service.yaml
```

**Deep Dive**:
- **Explicit Inclusion**: Kustomize only processes files listed here. If you add `configmap.yaml` later, it’s ignored unless added to `resources`.
- **Flexibility**: You can reference:
  - Local files (e.g., `nginx-deployment.yaml`).
  - Entire directories (e.g., `../base`).
  - Remote URLs (e.g., `https://example.com/deployment.yaml`).
- **Real-World Use**: In a microservices app, `resources` might list a dozen files—Deployments, Services, ConfigMaps—forming a complete app stack.

### 2. 🔧 Transformations Section
- **Purpose**: Defines customizations or modifications to apply to the resources.
- **Format**: Varies based on the transformation type (e.g., `commonLabels`, `patches`, `replicas`).

**Example**:
For simplicity, let’s add a common label to all resources:
```yaml
# k8s/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - nginx-deployment.yaml
  - nginx-service.yaml
commonLabels:
  company: KodeKloud
```

**Technical Breakdown**:
- **Common Labels**: The `commonLabels` field injects a key-value pair (e.g., `company: KodeKloud`) into the `metadata.labels` of every resource listed.
- **Applied Result**: After processing:
  - `nginx-deployment.yaml` gets `labels: { app: nginx, company: KodeKloud }` on both `metadata` and `spec.template.metadata`.
  - `nginx-service.yaml` gets `labels: { company: KodeKloud }` on `metadata`.
- **Why This Matters**: Labels are critical for organization, filtering (e.g., `kubectl get pods -l company=KodeKloud`), and tying resources to company branding or ownership.

**Beyond This Example**:
- **Patches**: Modify specific fields (e.g., `replicas: 3`).
  ```yaml
  patchesStrategicMerge:
    - patch.yaml  # Contains { spec: { replicas: 3 } }
  ```
- **Generators**: Auto-create ConfigMaps or Secrets from files.
- **Namespace**: Inject a namespace (e.g., `namespace: prod`).

**Nuance**: Transformations are additive and non-destructive—original files stay untouched, and Kustomize generates the modified output dynamically.

---

## 🔄 Running Kustomize: The `kustomize build` Command
With `kustomization.yaml` configured, you can process it using the `kustomize build` command:

```bash
kustomize build k8s/
```

### 🛠️ What Happens?
1. **Locates `kustomization.yaml`**: Kustomize looks for this file in the specified directory (`k8s/`).
2. **Imports Resources**: Pulls in `nginx-deployment.yaml` and `nginx-service.yaml` as listed under `resources`.
3. **Applies Transformations**: Adds the `company: KodeKloud` label to both resources.
4. **Generates Output**: Produces the final YAML, printed to the terminal.

**Sample Output** (abridged):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  labels:
    company: KodeKloud
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    company: KodeKloud
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
        company: KodeKloud
    spec:
      containers:
      - name: nginx
        image: nginx:latest
```

**Deep Dive**:
- **Label Propagation**: In the Deployment, `company: KodeKloud` appears in both `metadata.labels` (for the Deployment object) and `spec.template.metadata.labels` (for the Pods), ensuring consistency.
- **Validation**: The output is valid Kubernetes YAML, ready for `kubectl apply` or inspection.
- **Real-World Workflow**: Pipe the output to a file (`kustomize build k8s/ > final.yaml`) or apply it directly (`kustomize build k8s/ | kubectl apply -f -`).

---

## ✅ Key Takeaways
The `kustomization.yaml` file is the heart of Kustomize, boiling down to two fundamental components:
1. **Resources**: A list of YAML files to manage (e.g., `nginx-deployment.yaml`, `nginx-service.yaml`).
2. **Transformations**: Customizations to apply (e.g., adding `company: KodeKloud` via `commonLabels`).

**Why It’s Simple**:
- **Declarative**: You state *what* you want, not *how* to do it.
- **Modular**: Resources and transformations are cleanly separated.
- **Scalable**: Add more files or tweaks as your app grows.

**Real-World Context**: A team might use this setup as a base, then create overlays (e.g., `overlays/prod/kustomization.yaml`) to adjust `replicas` or namespaces, building on this foundation.

---

## 🎯 Conclusion: The Power of `kustomization.yaml`
The `kustomization.yaml` file unlocks Kustomize’s potential by defining your resources and customizations in one place. In this example, we managed an NGINX Deployment and Service, applying a common label with minimal effort. This simplicity—combined with Kustomize’s ability to generate tailored manifests—makes it a game-changer for Kubernetes configuration management.

**Next Steps**:
- Experiment with advanced transformations (e.g., `patchesStrategicMerge`, `namePrefix`).
- Explore overlays to extend this setup for multiple environments.
- Run `kustomize build` with your own manifests to see it in action!

---

