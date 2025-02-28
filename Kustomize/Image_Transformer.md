

# 🚀 Modifying Container Images with Kustomize: The Image Transformer

## 📖 Introduction: Transforming Images in Kubernetes
Kustomize’s **Image Transformer** is a specialized tool that lets you modify the container images used in your Kubernetes resources—such as Deployments—without altering the original YAML files. Whether you need to swap an image entirely (e.g., from `nginx` to `haproxy`), update its tag (e.g., from `latest` to `2.4`), or both, this transformer provides a flexible, declarative way to customize images across your configs. In this section, we’ll explore how it works, clarify potential confusion, and demonstrate its versatility with examples.

---

## 🛠️ The Basics: What Does the Image Transformer Do?
The Image Transformer searches your Kubernetes manifests for containers using a specified image and replaces or modifies that image according to rules you define in the `kustomization.yaml` file. It’s perfect for scenarios like:
- Switching images for testing (e.g., `nginx` to `haproxy`).
- Pinning versions with tags (e.g., `nginx:latest` to `nginx:2.4`).
- Combining both for precise control (e.g., `nginx:latest` to `haproxy:2.4`).

Let’s start with a simple example and build from there.

---

## 🌟 Example Setup: A Basic Deployment
Here’s a `deployment.yaml` file deploying an NGINX server:

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
        - name: web
          image: nginx
  ```

**Observation**: The container `web` uses the image `nginx` (implying `nginx:latest` by default, as no tag is specified).

---

## 🔍 Using the Image Transformer: Changing the Image
Let’s use Kustomize to replace `nginx` with `haproxy`.

### 🗂️ Define the `kustomization.yaml`
```yaml
# k8s/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
images:
  - name: nginx
    newName: haproxy
```

**Command**:
```bash
kustomize build k8s/
```

**Output (Abridged)**:
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
      - name: web
        image: haproxy
```

**Technical Breakdown**:
- **Fields Explained**:
  - `name: nginx`: The image to find in all containers across listed resources. It matches the `image` field’s base name (`nginx` here, ignoring tags for now).
  - `newName: haproxy`: The replacement image name. Kustomize swaps `nginx` for `haproxy` wherever it appears.
- **Scope**: Applies to all containers in all resources under `resources`. If `service.yaml` had a container with `image: nginx`, it’d change too.
- **Result**: The Deployment now uses `haproxy` (defaults to `haproxy:latest` since no tag is specified).

**Clarification**: The `name` in `images` refers to the image name (`nginx`), *not* the container name (`web`). This distinction is crucial—`name: web` in `kustomization.yaml` won’t work, as it’s unrelated to the container’s `name` field. This tripped me up initially, so I’m highlighting it to save you the same confusion!

**Real-World Use**: Swap `nginx` for `apache` during testing without editing `deployment.yaml`.

---

## 🌍 Modifying the Tag: Using `newTag`
What if you don’t want to change the image name but just pin a specific version? The Image Transformer can update the tag with `newTag`.

### 🗂️ Update `kustomization.yaml`
```yaml
# k8s/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
images:
  - name: nginx
    newTag: 2.4
```

**Output (Abridged)**:
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
      - name: web
        image: nginx:2.4
```

**Technical Breakdown**:
- **Fields Explained**:
  - `name: nginx`: Targets containers using `nginx` (with or without a tag).
  - `newTag: 2.4`: Sets the tag to `2.4`, overriding any existing tag (or adding it if none existed).
- **Behavior**: If the original image was `nginx:latest`, it becomes `nginx:2.4`. If it was `nginx` (no tag), it’s now explicitly `nginx:2.4`.
- **Precision**: Tags ensure reproducible builds—`latest` can shift unexpectedly, but `2.4` is fixed.

**Real-World Use**: Pin a stable version (e.g., `nginx:1.21`) in production instead of relying on `latest`.

---

## 🔧 Combining `newName` and `newTag`
For ultimate control, combine both to change the image *and* its tag.

### 🗂️ Update `kustomization.yaml`
```yaml
# k8s/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
images:
  - name: nginx
    newName: haproxy
    newTag: 2.4
```

**Output (Abridged)**:
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
      - name: web
        image: haproxy:2.4
```

**Technical Breakdown**:
- **Fields Combined**:
  - `name: nginx`: Finds `nginx` in the original config.
  - `newName: haproxy`: Replaces the image name.
  - `newTag: 2.4`: Sets the tag on the new image.
- **Result**: Transforms `nginx` (or `nginx:latest`) into `haproxy:2.4`.
- **Flexibility**: Adjusts both the image source and version in one go.

**Real-World Use**: Switch to `haproxy:2.4` for a load-balanced dev environment while keeping `nginx:latest` in the base config.

---

## 🔄 Applying the Changes
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
kubectl get deployment nginx-deployment -o jsonpath='{.spec.template.spec.containers[0].image}'
# Output: haproxy:2.4 (for the combined example)
```

**Debugging Tip**: Preview with `kustomize build k8s/` to confirm the transformation before applying.

---

## ✅ Key Features and Benefits
| Action             | Transformer Fields       | Benefit                              |
|--------------------|--------------------------|--------------------------------------|
| Change Image       | `name`, `newName`        | Swap images without editing YAML    |
| Update Tag         | `name`, `newTag`         | Pin versions for consistency        |
| Both               | `name`, `newName`, `newTag` | Full control over image and version |

**Scalability**: If you have 10 Deployments using `nginx`, one `images` entry updates them all—no manual edits needed.

**Gotcha**: The transformer matches the image name exactly. `nginx:1.20` won’t match `name: nginx` unless the tag is ignored or you use `digest` (advanced feature).

---

## 🎯 Conclusion: Precision Image Management
The Kustomize Image Transformer empowers you to modify container images with surgical precision—swapping names, updating tags, or both—all from the `kustomization.yaml` file. In our example, we transformed an NGINX Deployment into an HAProxy one, adjusted its tag, and combined both changes, showcasing the transformer’s versatility. This declarative approach keeps your base configs pristine while enabling environment-specific tweaks, making it a cornerstone of Kustomize’s power.

**Key Takeaways**:
- **Image vs. Container**: `name` targets the image, not the container name—don’t mix them up!
- **Flexibility**: Choose `newName`, `newTag`, or both to fit your needs.
- **Efficiency**: Scale image changes across multiple resources effortlessly.

**Next Steps**:
- Test swapping images in a local cluster (e.g., Minikube).
- Experiment with multiple `images` entries for multi-container Deployments.
- Explore advanced options like `digest` for SHA-based image pinning.

---

