
Let’s dive into the concept of a **declarative setup** in Kubernetes, focusing on how we can use **ArgoCD** to manage a Mono application as an example. I’ll break this down step-by-step in an easy-to-understand way, with a practical example to make it crystal clear.

---

### What Does "Declarative" Mean in Kubernetes?

In Kubernetes, a **declarative approach** means you define *what* you want your system to look like (the desired state) in files, rather than giving step-by-step instructions on *how* to make it happen. Think of it like writing a shopping list: you list the items you want (milk, bread, eggs), and someone else (Kubernetes) figures out how to get them for you.

You can create Kubernetes resources—like **deployments**, **secrets**, or **config maps**—in two ways:
1. **Imperative Way**: Using CLI commands like `kubectl create deployment my-app --image=nginx`. This is like telling Kubernetes exactly what to do, one command at a time.
2. **Declarative Way**: Writing a YAML file that describes the resource (e.g., a deployment) and then applying it with `kubectl apply -f my-file.yaml`. This tells Kubernetes, “Here’s what I want—make it happen.”

The declarative way is powerful because you can store these YAML files in a Git repository, track changes, and reuse them. That’s where **ArgoCD** comes in—it takes this idea further with a GitOps approach.

---

### What is ArgoCD and How Does It Fit In?

**ArgoCD** is a tool for **continuous delivery** in Kubernetes, built on the **GitOps** philosophy. GitOps means your Git repository becomes the single source of truth for your application’s configuration. Instead of manually running `kubectl` commands or using the ArgoCD UI/CLI to set up applications, you can define everything in YAML files (manifests) and let ArgoCD keep your cluster in sync with those files.

Just like Kubernetes resources, ArgoCD resources (e.g., applications, projects) can be defined declaratively in YAML and applied with `kubectl apply`. This makes your setup repeatable, version-controlled, and easier to manage.

---

### Example: Setting Up a Mono Application Declaratively

Let’s imagine we’re managing a simple **Mono application** (a single, unified app) in Kubernetes using ArgoCD. We’ll define everything in a Git repository and let ArgoCD handle the rest. Here’s how it works, step-by-step.

#### Step 1: Git Repository Structure

Picture a Git repository with this tree structure:

```
my-git-repo/
├── declarative/
    ├── manifests/
    │   ├── deployment.yaml    # Kubernetes Deployment for the Mono app
    │   └── service.yaml       # Kubernetes Service for the Mono app
    └── mono-app/
        └── application.yaml   # ArgoCD Application manifest
```

- **declarative/**: A top-level folder in the Git repo.
- **manifests/**: Contains the Kubernetes YAML files that define the Mono app’s resources (a deployment and a service).
- **mono-app/**: Contains the ArgoCD application YAML file that tells ArgoCD what to manage.

#### Step 2: The Kubernetes Manifests

Inside `declarative/manifests/`, we have two files:

- **`deployment.yaml`** (defines a deployment for our Mono app):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mono-app
  namespace: my-namespace
spec:
  replicas: 3
  selector:
    matchLabels:
      app: mono-app
  template:
    metadata:
      labels:
        app: mono-app
    spec:
      containers:
      - name: mono-app
        image: mycompany/mono-app:latest
```

- **`service.yaml`** (exposes the app via a service):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: mono-app-service
  namespace: my-namespace
spec:
  selector:
    app: mono-app
  ports:
  - port: 80
    targetPort: 8080
  type: LoadBalancer
```

These files describe the **desired state** of our Mono app: a deployment with 3 replicas and a service to make it accessible.

#### Step 3: The ArgoCD Application Manifest

Now, in `declarative/mono-app/`, we have `application.yaml`, which tells ArgoCD how to manage the Mono app:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mono-app
spec:
  project: default
  source:
    repoURL: 'https://github.com/your-username/my-git-repo.git'
    targetRevision: main
    path: declarative/manifests
  destination:
    server: 'https://kubernetes.default.svc'  # The target Kubernetes cluster
    namespace: my-namespace                   # Where to deploy the resources
  syncPolicy:
    automated: {}                            # Automatically sync changes
```

Let’s break down this file:
- **`metadata.name`**: Names the ArgoCD application “mono-app”.
- **`spec.project`**: Assigns it to the “default” ArgoCD project (you can create custom projects too).
- **`spec.source`**:
  - `repoURL`: The Git repository URL.
  - `targetRevision`: The branch (e.g., “main”) to watch.
  - `path`: Points to `declarative/manifests/`, where the deployment and service YAMLs live.
- **`spec.destination`**:
  - `server`: The Kubernetes cluster to deploy to (this URL is the default for in-cluster ArgoCD).
  - `namespace`: The namespace where the resources will be created.
- **`syncPolicy.automated`**: Tells ArgoCD to automatically apply changes from Git to the cluster.

#### Step 4: Applying the ArgoCD Application

To set this up:
1. Push all these files to your Git repository (`my-git-repo`).
2. Run this command from your local machine (assuming you have `kubectl` configured to talk to your cluster where ArgoCD is installed):
   ```
   kubectl apply -f declarative/mono-app/application.yaml
   ```

If there are no errors, ArgoCD will create an **Application** resource named “mono-app” in the cluster.

#### Step 5: What Happens Next?

Once the ArgoCD application is created:
- ArgoCD looks at the `source.path` (`declarative/manifests`) in the Git repo.
- It finds `deployment.yaml` and `service.yaml` there.
- It applies those manifests to the `my-namespace` namespace in the target cluster (`https://kubernetes.default.svc`).
- Because we set `syncPolicy: automated`, ArgoCD will continuously monitor the Git repo. If you update `deployment.yaml` (e.g., change the image version) and push the change, ArgoCD will automatically apply it to the cluster.

If you didn’t use `automated`, you’d need to manually trigger a sync via the ArgoCD UI or CLI (`argocd app sync mono-app`).

---

### Why Is This Declarative?

This setup is **declarative** because:
- Everything is defined in YAML files: the Kubernetes resources (deployment, service) and the ArgoCD application.
- You don’t tell ArgoCD *how* to create the deployment or service step-by-step—you just say *what* you want by pointing to the manifests in Git.
- ArgoCD ensures the cluster’s actual state matches the desired state in Git.

It’s like handing over your shopping list (the YAML files) to ArgoCD and trusting it to keep your kitchen (the cluster) stocked.

---

### Benefits of This Approach

1. **Version Control**: All configurations are in Git, so you can track changes, roll back, or audit them.
2. **Consistency**: The same manifests work across environments (dev, staging, prod) by tweaking the `destination` or `path`.
3. **Automation**: With `syncPolicy: automated`, updates happen without manual intervention.
4. **Collaboration**: Teams can collaborate via pull requests in Git.

---

### Wrapping Up with Our Example

Imagine you’re running a Mono app (say, a simple web server). You:
1. Store its deployment and service YAMLs in `declarative/manifests/`.
2. Define an ArgoCD application in `declarative/mono-app/application.yaml` to manage it.
3. Apply the application manifest with `kubectl apply`.
4. Sit back as ArgoCD deploys and maintains your app based on Git.

If you tweak the deployment (e.g., scale replicas to 5) and push to Git, ArgoCD updates the cluster automatically. It’s a hands-off, Git-driven way to manage your app—declarative and simple!

Does that make sense? Let me know if you’d like me to clarify anything further!
