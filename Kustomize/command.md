
# 🚀 Applying and Deleting Resources with Kustomize: From Build to Cluster

## 📖 Recap: The `kustomize build` Command
This command processes your `kustomization.yaml` file, imports the listed resources (e.g., Deployments, Services), applies transformations (e.g., adding labels), and outputs the final Kubernetes manifests to the console. However, it’s critical to understand that `kustomize build` alone doesn’t deploy anything to your cluster—it’s a dry run. If you check your Kubernetes cluster with commands like `kubectl get pods`, `kubectl get deployments`, or `kubectl get services`, you’ll see no changes. So, how do we bridge the gap from building configs to applying them? Let’s dive in.

---

## 🛠️ Applying Kustomize Configurations to a Cluster
Kustomize generates manifests, but applying them to Kubernetes requires integration with `kubectl`. There are two primary methods to do this, both leveraging the output of `kustomize build`. Let’s explore each approach with our example directory:

```
k8s/
├── nginx-deployment.yaml
├── nginx-service.yaml
└── kustomization.yaml
```

- **kustomization.yaml** (from the previous example):
  ```yaml
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - nginx-deployment.yaml
    - nginx-service.yaml
  commonLabels:
    company: KodeKloud
  ```

### 1. 🔄 Using `kustomize build` with a Pipe to `kubectl apply`
**Command**:
```bash
kustomize build k8s/ | kubectl apply -f -
```

**How It Works**:
- **Left Side**: `kustomize build k8s/` generates the final YAML for the NGINX Deployment and Service, including the `company: KodeKloud` label.
- **Pipe (`|`)**: A Linux shell feature that redirects the output of `kustomize build` (the YAML) into the input of the next command.
- **Right Side**: `kubectl apply -f -` reads the YAML from standard input (`-`) and applies it to the cluster.

**Technical Breakdown**:
- **Output Redirection**: The pipe (`|`) is a universal shell utility, not specific to Kubernetes or Kustomize. It’s like a conveyor belt moving data from one tool to another.
- **kubectl apply**: This command reconciles the cluster state with the provided YAML, creating or updating the NGINX Deployment and Service.
- **Result**: After running this, you’ll see:
  - A Deployment (`nginx-deployment`) with 1 pod.
  - A Service (`nginx-service`) exposing port 80.
  - Both resources labeled with `company: KodeKloud`.

**Real-World Example**:
- In a CI/CD pipeline (e.g., GitHub Actions), you might script this to deploy automatically:
  ```bash
  kustomize build k8s/ | kubectl apply -f -
  kubectl rollout status deployment/nginx-deployment
  ```

### 2. 📦 Native `kubectl` Integration with `-k`
**Command**:
```bash
kubectl apply -k k8s/
```

**How It Works**:
- **`-k` Flag**: Since Kubernetes 1.14, `kubectl` has built-in Kustomize support. The `-k` flag tells `kubectl` to:
  1. Find `kustomization.yaml` in the specified directory (`k8s/`).
  2. Run the equivalent of `kustomize build` internally.
  3. Apply the resulting manifests directly to the cluster.
- **No Pipe Needed**: This is a streamlined, one-step alternative to the pipe method.

**Deep Dive**:
- **Convenience**: No separate `kustomize` binary is required if using a recent `kubectl` version (though standalone Kustomize might offer newer features).
- **Output**: Identical to the pipe method—NGINX Deployment and Service are created with the `company: KodeKloud` label.
- **Debugging Tip**: Use `kubectl kustomize k8s/` to preview the YAML without applying it (similar to `kustomize build`).

**Real-World Context**: Teams often use `-k` in local workflows for its simplicity, reserving the pipe method for scripts or older setups.

---

## ⚠️ Deleting Resources with Kustomize
Just as Kustomize helps create resources, it can also delete them. The process mirrors applying, swapping `apply` for `delete`.

### 1. 🔄 Using `kustomize build` with a Pipe to `kubectl delete`
**Command**:
```bash
kustomize build k8s/ | kubectl delete -f -
```

**How It Works**:
- **Left Side**: `kustomize build k8s/` generates the same YAML as before.
- **Pipe (`|`)**: Sends the YAML to `kubectl delete`.
- **Right Side**: `kubectl delete -f -` removes the resources (Deployment and Service) from the cluster based on the YAML.

**Technical Details**:
- **Exact Match**: `kubectl delete` uses the YAML to identify resources by `kind`, `metadata.name`, and sometimes `namespace`. Here, it deletes `nginx-deployment` and `nginx-service`.
- **Result**: The cluster returns to its pre-applied state—no NGINX pods or services remain.

**Use Case**: Useful in scripts to clean up a test environment:
```bash
kustomize build k8s/ | kubectl delete -f -
echo "Environment cleaned."
```

### 2. 📦 Native `kubectl delete` with `-k`
**Command**:
```bash
kubectl delete -k k8s/
```

**How It Works**:
- **`-k` Flag**: `kubectl` processes `kustomization.yaml`, builds the manifests, and deletes the matching resources in one go.
- **Simplicity**: Like `apply -k`, this avoids the pipe, leveraging `kubectl`’s Kustomize integration.

**Nuance**: The `-k` flag essentially means “Kustomize this directory” for both applying and deleting, making it intuitive once you know `-f` (file) vs. `-k` (Kustomize).

**Real-World Example**: A developer might use this to tear down a dev environment:
```bash
kubectl delete -k k8s/
kubectl get all  # Confirms nothing remains
```

---

## ✅ All Commands and Their Uses
Here’s a comprehensive list of commands discussed, with their purposes and practical applications:

| Command                                      | Use Case                                      | Description                                                                 |
|----------------------------------------------|-----------------------------------------------|-----------------------------------------------------------------------------|
| `kustomize build k8s/`                       | Preview manifests                            | Builds and outputs the final YAML to stdout without applying it.            |
| `kustomize build k8s/ | kubectl apply -f -` | Apply resources                              | Builds YAML and pipes it to `kubectl apply` to create/update resources.     |
| `kustomize build k8s/ | kubectl delete -f -`| Delete resources                             | Builds YAML and pipes it to `kubectl delete` to remove resources.           |
| `kubectl apply -k k8s/`                      | Apply resources (native)                     | Uses `kubectl`’s built-in Kustomize to build and apply in one step.         |
| `kubectl delete -k k8s/`                     | Delete resources (native)                    | Uses `kubectl`’s built-in Kustomize to build and delete in one step.        |
| `kubectl kustomize k8s/`                     | Preview manifests (native)                   | Like `kustomize build`, but via `kubectl`—outputs YAML without applying.    |
| `kustomize build k8s/ > output.yaml`         | Save manifests to a file                     | Builds YAML and saves it to a file for inspection or later use.             |
| `kubectl apply -f output.yaml`               | Apply saved manifests                        | Applies a previously saved YAML file (alternative workflow).                |

**Additional Tips**:
- **Dry Run**: Add `--dry-run=client` to `kubectl apply` commands to test without changes (e.g., `kubectl apply -k k8s/ --dry-run=client`).
- **Verbose Output**: Use `-v=6` with `kubectl` for detailed logs (e.g., `kubectl apply -k k8s/ -v=6`).
- **CI/CD Integration**: Combine with `kubectl rollout status` to verify deployments:
  ```bash
  kubectl apply -k k8s/
  kubectl rollout status deployment/nginx-deployment
  ```

---

## 🎯 Conclusion: Bringing Kustomize to Life
The `kustomize build` command is a powerful starting point, but applying and deleting resources ties it to your Kubernetes cluster. Whether you use the pipe method (`kustomize build | kubectl`) for flexibility or the native `-k` flag for simplicity, Kustomize seamlessly integrates with `kubectl` to manage your resources. In our example, we created and deleted an NGINX Deployment and Service, complete with a `company: KodeKloud` label, showcasing Kustomize’s practical utility.

**Key Insights**:
- **Build vs. Apply**: `kustomize build` is a preview; pairing it with `kubectl` makes it actionable.
- **Symmetry**: Apply and delete follow the same pattern, just with different `kubectl` verbs.
- **Flexibility**: Choose between pipe or `-k` based on your workflow—both get the job done.

**Next Steps**:
- Test these commands in a local cluster (e.g., Minikube).
- Explore multi-environment setups with overlays to see Kustomize’s full power.
- Automate with scripts or CI/CD tools for real-world deployment workflows.

---

