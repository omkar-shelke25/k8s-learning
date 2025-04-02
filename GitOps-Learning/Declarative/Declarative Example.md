In this demo, we’ll explore how to manage a single ArgoCD application declaratively using YAML files stored in a Git repository, shifting away from the ArgoCD CLI and UI methods we’ve used previously. This approach aligns with the GitOps philosophy, where the desired state of applications is defined in code and version-controlled.

### Background: From UI/CLI to Declarative Management
So far, you’ve created ArgoCD applications using the ArgoCD command-line interface (CLI) and the user interface (UI). When you define an application in the UI—specifying metadata, source, and destination details—ArgoCD generates a YAML specification behind the scenes. This YAML file represents the ArgoCD application, much like how Kubernetes resources (e.g., deployments or services) are defined in YAML manifests. The key advantage of this approach is that these YAML files can be stored in a Git repository, enabling a declarative management process where ArgoCD automatically creates and manages the applications based on these specifications.

### Demo Setup: The Git Repository Structure
In this example, we’re working with a GitOps repository that contains a `declarative` directory. Inside this directory, there’s a subdirectory—let’s call it `mono-app` (sometimes referred to as "MonoApplication" or "Monorepo app" in the transcript)—designed to manage a single ArgoCD application. Within `mono-app`, we have a file named `geocentric app.yaml`, which is the YAML definition specific to this ArgoCD application.

#### Contents of `geocentric app.yaml`
The `geocentric app.yaml` file includes the following key components:
- **Kind**: `Application` (indicating it’s an ArgoCD application resource).
- **API Version**: Uses the ArgoCD-specific API version.
- **Project**: Set to `default`, meaning it belongs to the default ArgoCD project.
- **Source Details**:
  - **Repository URL**: The URL of the Git repository.
  - **Path**: Points to `declarative/manifests/geocentric-model`, a directory within the same repository containing the Kubernetes manifests for the application.
- **Destination Details**:
  - **Target Cluster**: Specifies the Kubernetes cluster where the application will be deployed.
  - **Namespace**: The namespace in the cluster where the application resources will reside.
- **Sync Policies**:
  - **Create Namespace**: Automatically creates the namespace if it doesn’t exist.
  - **Auto-Sync**: Enables automatic synchronization of the application with the Git repository.
  - **Self-Heal**: Ensures the cluster state matches the desired state in Git by correcting any manual changes.

The `declarative/manifests/geocentric-model` directory contains two Kubernetes manifests:
- **Deployment YAML**: Defines the pods for the application.
- **Service YAML**: Exposes the application’s UI on a specific port (e.g., 30682 in this demo).

This setup means that `geocentric app.yaml` tells ArgoCD where to find the application’s manifests and how to deploy them.

### Creating the Application Declaratively
Unlike previous methods where you used the CLI or UI, here you’ll create the application declaratively by applying the YAML file directly to the cluster. Since ArgoCD is installed and running in the cluster, it watches for `Application` resources and manages them accordingly.

#### Steps to Create the Application
1. **Navigate to the YAML File**:
   - In your local clone of the GitOps repository, go to the `declarative/mono-app` directory where `geocentric app.yaml` is located.
   
2. **Apply the YAML File**:
   - Use the `kubectl` command to create the ArgoCD application resource in the `argocd` namespace:
     ```bash
     kubectl apply -n argocd -f geocentric app.yaml
     ```
   - This command registers the application with ArgoCD by creating an `Application` resource in the cluster.

3. **Verify the Application Creation**:
   - Check that the application has been created using one of these commands:
     ```bash
     argocd app list
     ```
     or
     ```bash
     kubectl -n argocd get applications
     ```
   - You should see a new application named `geocentric-model-app` listed, with its sync status as `Synced` (thanks to the auto-sync policy).

4. **Inspect the Application in the UI**:
   - Open the ArgoCD UI and locate the `geocentric-model-app` application.
   - Verify that it has deployed the resources from the `declarative/manifests/geocentric-model` directory: a deployment (running pods) and a service (exposing the UI).

### What the Application Does
The deployed application, `geocentric-model-app`, is a simple demo representing a geocentric solar system model—a historical view where Earth is the center of the universe, and the Sun and planets orbit around it. The service exposes the application’s UI on port `30682`, allowing you to access and interact with this model.

### Key Takeaway: The Declarative Approach
In this demo, you didn’t rely on imperative commands via the CLI or manual inputs in the UI. Instead, you:
- Defined the ArgoCD application in `geocentric app.yaml`.
- Stored it in a Git repository.
- Applied it to the cluster with `kubectl apply -f`.

ArgoCD then detected this new `Application` resource and automatically synchronized the cluster state with the manifests in Git, deploying the deployment and service. This declarative method ensures that the application’s desired state is fully captured in version-controlled YAML files, promoting consistency, repeatability, and automation across environments.

### Summary of the Process
To manage a single ArgoCD application declaratively:
1. **Define the Application**: Create a YAML file (e.g., `geocentric app.yaml`) specifying the source (Git repo and manifest path), destination (cluster and namespace), and sync policies.
2. **Store in Git**: Commit this file to a Git repository under a structured directory (e.g., `declarative/mono-app`).
3. **Apply to Cluster**: Use `kubectl apply -f` to create the `Application` resource in the `argocd` namespace.
4. **Let ArgoCD Manage**: ArgoCD detects the resource, syncs the manifests from Git, and deploys the application to the cluster.

This approach leverages GitOps principles, making it easier to manage applications at scale while maintaining a clear audit trail of changes. If you have further questions or need clarification, feel free to ask!
