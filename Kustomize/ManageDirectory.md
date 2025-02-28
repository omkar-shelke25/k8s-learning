
# 🚀 Scaling Kustomize: Managing Resources Across Multiple Directories

## 📖 Introduction: Beyond the Basics
So far, we’ve covered the essentials of the `kustomization.yaml` file—listing resources and applying simple transformations like adding labels. While this is a solid foundation, Kustomize offers far more power and flexibility. Even with our basic knowledge, we can tackle sophisticated tasks, such as managing Kubernetes manifests spread across multiple directories. This section explores how Kustomize simplifies this process, evolving from a flat structure to a modular, scalable hierarchy. Let’s dive into a practical example and see Kustomize shine.

---

## 🛠️ Initial Setup: A Flat Directory Structure
Imagine a `k8s/` directory containing all your Kubernetes manifests in one place:

```
k8s/
├── api-deployment.yaml
├── api-service.yaml
├── db-deployment.yaml
├── db-service.yaml
```

- **api-deployment.yaml**:
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

- **api-service.yaml**:
  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: api-service
  spec:
    selector:
      app: api
    ports:
    - port: 80
  ```

- **db-deployment.yaml** and **db-service.yaml**: Similar configs for a database, using `app: db` and `image: my-db:latest`.

**Applying Without Kustomize**:
```bash
kubectl apply -f k8s/
```

**How It Works**:
- `kubectl apply -f k8s/` processes all `.yaml` files in the directory, deploying the API and database Deployments and Services.
- **Simplicity**: No Kustomize needed—just standard Kubernetes behavior.

**Real-World Context**: This works fine for a small app with 4-5 files. You get an API pod and service, plus a database pod and service, all running in minutes.

---

## ⚠️ The Problem: Growing Complexity
Over time, your app evolves. The `k8s/` directory balloons to 20, 30, or even 50 YAML files—ConfigMaps, Secrets, Ingresses, and more. It becomes a cluttered mess:
- Hard to navigate (e.g., finding the database Service among dozens of files).
- Prone to errors (e.g., accidentally editing `api-service.yaml` when you meant `db-service.yaml`).
- No logical grouping (e.g., API vs. database resources are mixed).

### 🗂️ Solution Attempt: Subdirectories
To organize, you split the files into subdirectories:

```
k8s/
├── api/
│   ├── api-deployment.yaml
│   ├── api-service.yaml
├── db/
│   ├── db-deployment.yaml
│   ├── db-service.yaml
```

**New Apply Process**:
```bash
kubectl apply -f k8s/api/
kubectl apply -f k8s/db/
```

**Technical Breakdown**:
- **Granularity**: Each `kubectl apply -f` targets a specific subdirectory, deploying its YAML files.
- **Result**: The same API and database resources are created, but now they’re neatly organized.

**Real-World Example**: A microservices team might have `/frontend/`, `/backend/`, and `/storage/` subdirectories, each with its own manifests.

**Downside**:
- **Manual Effort**: You must run `kubectl apply` for each subdirectory—two commands here, but 10+ for a larger app.
- **CI/CD Pain**: Your pipeline (e.g., Jenkins, GitHub Actions) needs logic to loop through all subdirectories:
  ```bash
  for dir in k8s/*/; do kubectl apply -f "$dir"; done
  ```
- **Maintenance**: Adding a new subdirectory (e.g., `/cache/`) requires updating scripts or manually applying it. This doesn’t scale.

---

## 🌟 Kustomize to the Rescue: Centralizing with `kustomization.yaml`
Kustomize simplifies this by letting you manage all subdirectories from a single command. Let’s add a `kustomization.yaml` file at the root:

### 1. 🔍 Initial Approach: Listing All Files
**Root `kustomization.yaml`**:
```yaml
# k8s/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - api/api-deployment.yaml
  - api/api-service.yaml
  - db/db-deployment.yaml
  - db/db-service.yaml
```

**Apply Commands**:
- **With Pipe**:
  ```bash
  kustomize build k8s/ | kubectl apply -f -
  ```
- **Native `kubectl`**:
  ```bash
  kubectl apply -k k8s/
  ```

**How It Works**:
- **Resources Field**: Lists relative paths to all YAML files across subdirectories.
- **Kustomize Build**: Processes `kustomization.yaml`, imports the four files, and generates a unified YAML output.
- **kubectl Apply**: Deploys everything in one shot—API and database resources are created together.

**Benefits**:
- **Single Command**: No need to navigate subdirectories or run multiple `kubectl` commands.
- **CI/CD Simplicity**: One pipeline step (`kubectl apply -k k8s/`) covers all resources.

**Real-World Context**: A small team with 2-3 subdirectories finds this sufficient. The root `kustomization.yaml` acts as a central manifest registry.

---

## ⚠️ Scaling Challenge: Resource List Explosion
As your app grows, so does the number of subdirectories:

```
k8s/
├── api/
│   ├── api-deployment.yaml
│   ├── api-service.yaml
├── db/
│   ├── db-deployment.yaml
│   ├── db-service.yaml
├── cache/
│   ├── cache-deployment.yaml
│   ├── cache-service.yaml
├── kafka/
│   ├── kafka-deployment.yaml
│   ├── kafka-service.yaml
```

**Updated `kustomization.yaml`**:
```yaml
# k8s/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - api/api-deployment.yaml
  - api/api-service.yaml
  - db/db-deployment.yaml
  - db/db-service.yaml
  - cache/cache-deployment.yaml
  - cache/cache-service.yaml
  - kafka/kafka-deployment.yaml
  - kafka/kafka-service.yaml
```

**Problem**:
- **Clutter**: The `resources` list balloons—8 files here, but imagine 50+ in a large app.
- **Maintenance**: Adding a new file (e.g., `kafka-configmap.yaml`) requires editing the root `kustomization.yaml`.
- **Readability**: It’s a laundry list, obscuring the structure and intent.

**Technical Insight**: While functional, this approach violates modularity principles. It’s a valid solution but not optimal as complexity scales.

---

## 🌈 Improved Approach: Nested `kustomization.yaml` Files
Kustomize supports a hierarchical structure by placing `kustomization.yaml` files in subdirectories, delegating resource management to each level.

### 🗂️ New Structure
```
k8s/
├── api/
│   ├── api-deployment.yaml
│   ├── api-service.yaml
│   ├── kustomization.yaml
├── db/
│   ├── db-deployment.yaml
│   ├── db-service.yaml
│   ├── kustomization.yaml
├── cache/
│   ├── cache-deployment.yaml
│   ├── cache-service.yaml
│   ├── kustomization.yaml
├── kafka/
│   ├── kafka-deployment.yaml
│   ├── kafka-service.yaml
│   ├── kustomization.yaml
├── kustomization.yaml  # Root
```

#### Subdirectory `kustomization.yaml` Files
- **api/kustomization.yaml**:
  ```yaml
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - api-deployment.yaml
    - api-service.yaml
  ```

- **db/kustomization.yaml**:
  ```yaml
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - db-deployment.yaml
    - db-service.yaml
  ```

- **cache/kustomization.yaml** and **kafka/kustomization.yaml**: Similar, listing their respective files.

#### Root `kustomization.yaml`
```yaml
# k8s/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - api/
  - db/
  - cache/
  - kafka/
```

**Apply Commands** (Unchanged):
- **With Pipe**:
  ```bash
  kustomize build k8s/ | kubectl apply -f -
  ```
- **Native `kubectl`**:
  ```bash
  kubectl apply -k k8s/
  ```

**How It Works**:
- **Root Level**: The root `kustomization.yaml` references entire directories (e.g., `api/`) instead of individual files.
- **Subdirectory Lookup**: Kustomize sees `api/` in `resources`, navigates to `api/kustomization.yaml`, and processes its `resources` (e.g., `api-deployment.yaml`, `api-service.yaml`).
- **Recursion**: This repeats for `db/`, `cache/`, and `kafka/`, aggregating all manifests into one output.
- **Result**: All Deployments and Services across subdirectories are deployed with a single command.

**Technical Deep Dive**:
- **Modularity**: Each subdirectory manages its own resources, keeping the root clean and focused.
- **Scalability**: Add a new subdirectory (e.g., `logging/`) with its own `kustomization.yaml`, then append `logging/` to the root file—done.
- **Output**: `kustomize build k8s/` generates a unified YAML stream with all 8 resources, ready for `kubectl`.

**Real-World Example**: A large app might have 10+ subdirectories (e.g., `frontend/`, `backend/`, `monitoring/`), each with 5-10 files. Nested `kustomization.yaml` files keep this manageable.

---

## ✅ Benefits of the Nested Approach
| Aspect               | 🔍 Single File List         | 🌈 Nested `kustomization.yaml` |
|----------------------|-----------------------------|-------------------------------|
| **Readability**      | Cluttered with many files   | Clean, directory-focused      |
| **Maintenance**      | Edit root for every file    | Edit subdirectory locally     |
| **Scalability**      | Breaks down with growth     | Scales effortlessly           |
| **Encapsulation**    | No separation of concerns   | Logical grouping per module   |

**Nuance**: The single-file approach suits tiny projects, but nested configs are the gold standard for teams or complex apps.

---

## 🎯 Conclusion: Kustomize’s Power Unleashed
Kustomize transforms a messy, multi-directory Kubernetes setup into a streamlined, single-command workflow. By evolving from a flat `kubectl apply -f` per subdirectory to a root `kustomization.yaml`—and ultimately to nested `kustomization.yaml` files—we’ve tackled scaling challenges head-on. Whether you use `kustomize build | kubectl apply` or `kubectl apply -k`, Kustomize ensures your configs remain organized, maintainable, and deployable with ease.

**Key Takeaways**:
- **Flat to Structured**: Kustomize bridges the gap from disorganized files to modular subdirectories.
- **Hierarchy Wins**: Nested `kustomization.yaml` files keep complexity in check.
- **One Command**: Deploy everything, no matter how many subdirectories, with a single call.

**Next Steps**:
- Experiment with this structure in a local cluster (e.g., Minikube).
- Add transformations (e.g., `commonLabels`) to subdirectories for customization.
- Integrate into a CI/CD pipeline for automated, scalable deployments.

---
