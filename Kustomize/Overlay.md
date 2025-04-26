Below are detailed, structured notes on using **Kustomize** for managing Kubernetes configurations with a focus on **customization.yaml** files and the **overlays** mechanism. These notes consolidate the concepts from the provided transcript, explain how to customize Kubernetes configurations across multiple environments (e.g., development, staging, production), and include practical examples with folder structures and YAML configurations.

---

## Kustomize: Customizing Kubernetes Configurations with Overlays

### Overview
Kustomize is a tool for customizing Kubernetes configurations in a declarative manner. It allows you to define a **base configuration** (shared across environments) and apply environment-specific customizations using **overlays**. This is particularly useful for managing multiple environments (e.g., development, staging, production) with tailored configurations.

The primary mechanism for environment-specific customization is the use of **overlays**, which apply **patches** to modify base configurations or introduce new resources.

### Key Concepts
1. **Base Configuration**:
   - Contains shared Kubernetes configurations used across all environments.
   - Defined in a `base` directory with a `kustomization.yaml` file that lists resources (e.g., deployments, services).
   - Acts as the default configuration before environment-specific changes are applied.

2. **Overlays**:
   - Environment-specific directories (e.g., `dev`, `staging`, `prod`) that contain a `kustomization.yaml` file.
   - Each overlay references the base configuration and applies patches or adds new resources.
   - Patches modify specific fields in the base configuration (e.g., changing the number of replicas).
   - Overlays can also introduce new resources not present in the base.

3. **kustomization.yaml**:
   - A YAML file that defines resources, bases, and patches.
   - In the `base` directory, it lists shared resources.
   - In overlay directories, it specifies the path to the base configuration and any patches or additional resources.

4. **Patches**:
   - Used in overlays to modify specific fields in the base configuration.
   - Can be defined as strategic merge patches (YAML files) or JSON patches.
   - Allow fine-grained control over environment-specific changes.

5. **Relative Paths**:
   - Overlays reference the base configuration using a relative path (e.g., `../../base`).
   - The `..` syntax navigates up one directory level.

### Folder Structure
A typical Kustomize project has the following structure:
```
kustomize-project/
├── base/
│   ├── nginx-deployment.yaml
│   └── kustomization.yaml
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── patch-replicas.yaml
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   └── patch-replicas.yaml
│   ├── prod/
│   │   ├── kustomization.yaml
│   │   ├── patch-replicas.yaml
│   │   └── grafana-deployment.yaml
```

- **base/**: Contains shared configurations.
- **overlays/**: Contains subdirectories for each environment (`dev`, `staging`, `prod`).
- Each environment directory has its own `kustomization.yaml` and optional patch files or new resources.

### Step-by-Step Implementation

#### 1. Define the Base Configuration
The `base` directory contains the default Kubernetes configurations shared across all environments.

**Example: `base/nginx-deployment.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 1 # Default replicas
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
        ports:
        - containerPort: 80
```

**Example: `base/kustomization.yaml`**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - nginx-deployment.yaml
```

- The `kustomization.yaml` file lists all resources in the `base` directory.
- This configuration defines a simple Nginx deployment with 1 replica.

#### 2. Create Overlays for Each Environment
Each environment (`dev`, `staging`, `prod`) has its own directory under `overlays`. The `kustomization.yaml` file in each overlay:
- References the `base` directory using a relative path.
- Applies patches to modify the base configuration.
- Optionally includes new resources specific to the environment.

##### Development Environment
**Example: `overlays/dev/patch-replicas.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 2 # Change replicas to 2 for dev
```

**Example: `overlays/dev/kustomization.yaml`**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base # Relative path to base directory
patchesStrategicMerge:
  - patch-replicas.yaml
```

- **bases**: Specifies the relative path to the `base` directory (`../../base` navigates up two levels from `dev` to the project root, then into `base`).
- **patchesStrategicMerge**: Lists patch files that modify the base configuration.
- This configuration changes the number of replicas to 2 for the `dev` environment.

##### Staging Environment
**Example: `overlays/staging/patch-replicas.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3 # Change replicas to 3 for staging
```

**Example: `overlays/staging/kustomization.yaml`**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
patchesStrategicMerge:
  - patch-replicas.yaml
```

- Similar to the `dev` overlay, but sets replicas to 3 for the `staging` environment.

##### Production Environment
The production environment may include both patches and new resources.

**Example: `overlays/prod/patch-replicas.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 5 # Change replicas to 5 for prod
```

**Example: `overlays/prod/grafana-deployment.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana-deployment
  labels:
    app: grafana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
```

**Example: `overlays/prod/kustomization.yaml`**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
patchesStrategicMerge:
  - patch-replicas.yaml
resources:
  - grafana-deployment.yaml
```

- **patchesStrategicMerge**: Modifies the Nginx deployment to have 5 replicas.
- **resources**: Adds a new Grafana deployment, which is unique to the `prod` environment.
- The `grafana-deployment.yaml` file does not exist in the `base` directory, demonstrating that overlays can introduce new resources.

#### 3. Apply Kustomize Configurations
To generate the final Kubernetes manifests for an environment, run the `kustomize` command:

```bash
# For development environment
kustomize build overlays/dev

# For staging environment
kustomize build overlays/staging

# For production environment
kustomize build overlays/prod
```

Alternatively, apply directly to a Kubernetes cluster using `kubectl`:

```bash
# Apply development configuration
kustomize build overlays/dev | kubectl apply -f -

# Apply production configuration
kustomize build overlays/prod | kubectl apply -f -
```

#### 4. Understanding Relative Paths
In the `kustomization.yaml` files for overlays, the `bases` field uses a relative path to locate the `base` directory. For example:
- From `overlays/dev/kustomization.yaml`, the path `../../base` means:
  - `..` (go up from `dev` to `overlays`).
  - `..` (go up from `overlays` to the project root).
  - `base` (enter the `base` directory).

This ensures Kustomize can locate the `base/kustomization.yaml` file and its resources.

### Key Points
- **Base vs. Overlays**:
  - **Base**: Shared configurations (e.g., default replicas, container images).
  - **Overlays**: Environment-specific customizations (e.g., different replicas, new resources).
- **Patches**: Modify existing resources (e.g., changing replicas from 1 to 2).
- **New Resources**: Overlays can include resources not present in the base (e.g., Grafana in production).
- **kustomization.yaml**:
  - In `base`: Lists shared resources.
  - In overlays: References the base, applies patches, and includes new resources.
- **Flexibility**: Overlays are not limited to patches; they can add entirely new configurations.

### Example Output
Running `kustomize build overlays/dev` generates the following manifest (simplified):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 2 # Patched for dev
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
        ports:
        - containerPort: 80
```

For `overlays/prod`, the output includes both the patched Nginx deployment and the new Grafana deployment:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 5 # Patched for prod
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
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana-deployment
  labels:
    app: grafana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
```

### Best Practices
1. **Keep Base Simple**: Include only shared, default configurations in the `base` directory to avoid unnecessary complexity.
2. **Modular Patches**: Use separate patch files for each change (e.g., one for replicas, another for image tags) to improve maintainability.
3. **Validate Configurations**: Test each overlay with `kustomize build` to ensure the generated manifests are correct.
4. **Version Control**: Store the Kustomize project in a Git repository to track changes across environments.
5. **Document Overlays**: Clearly document the purpose of each overlay and patch to aid collaboration.

### Common Use Cases
- **Scaling**: Adjust the number of replicas based on environment needs (e.g., 1 for dev, 5 for prod).
- **Resource Limits**: Set different CPU/memory limits for dev (minimal) vs. prod (higher).
- **Feature Toggles**: Enable or disable features by modifying container environment variables.
- **Environment-Specific Services**: Deploy monitoring tools (e.g., Grafana) only in production.

---

These notes provide a comprehensive guide to using Kustomize with overlays, including practical examples and best practices. Let me know if you need further clarification or additional examples!overla
