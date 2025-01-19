### **Deployment YAML Explanation**
The YAML defines a Kubernetes Deployment with the following key attributes:

#### **1. Metadata**
- **name**: `testing` - The name of the deployment.
- **labels**: `app: web` - A label applied to all resources created by this Deployment for identification.

#### **2. Spec**
- **strategy**: Defines the Deployment strategy as `RollingUpdate`, with:
  - **maxUnavailable: 25%**: Maximum 25% of Pods can be unavailable during updates.
  - **maxSurge: 25%**: Allows up to 25% extra Pods above the desired replicas during updates.
- **replicas**: `10` - Specifies 10 Pods for this deployment.
- **selector**: Matches Pods with the label `app: web`.
- **template**: Defines the Pod template to be used:
  - **metadata**: Label `app: web` is applied.
  - **spec**: Contains the container specifications:
    - **name**: `nginx-web` - Name of the container.
    - **image**: `nginx` - The container image used for the application.

---

### **Commands Explanation**

#### **1. Check Deployment, ReplicaSets, and Pods**
```bash
k get deploy
```
- Lists all deployments in the cluster, showing their desired, current, and available replicas.

```bash
k get rs
```
- Lists all ReplicaSets in the cluster. ReplicaSets manage the Pods for the Deployment.

```bash
k get po
```
- Lists all Pods, showing their status (e.g., Running, Pending, or Terminating).

#### **2. Update the Deployment Image**
```bash
k set image deploy/testing nginx-web=nginx:1.12 --record
```
- Updates the container `nginx-web` in the `testing` deployment to use the `nginx:1.12` image.
- `--record`: Records the change in the deployment's revision history for rollback purposes.

#### **3. Monitor Rollout Progress**
```bash
k rollout status deploy/testing
```
- Checks the status of the Deployment's rollout, ensuring all replicas are updated without errors.

#### **4. View Rollout History**
```bash
k rollout history deploy/testing
```
- Displays the revision history of the Deployment. Includes changes such as image updates.

#### **5. Undo Deployment Rollout**
```bash
k rollout undo deploy/testing --to-revision=1
```
- Rolls back the Deployment to a specific revision (`1` in this case). Useful if the latest changes caused issues.

---

### **Command Uses**

| **Command**                          | **Purpose**                                                                                   |
|--------------------------------------|-----------------------------------------------------------------------------------------------|
| `k get deploy`                       | View current deployments, replica count, and availability.                                    |
| `k get rs`                           | Check ReplicaSets and their associated Pods.                                                 |
| `k get po`                           | Verify the status of individual Pods.                                                        |
| `k set image`                        | Update the container image used in a Deployment.                                             |
| `k rollout status`                   | Monitor the progress of an ongoing rollout.                                                  |
| `k rollout history`                  | Review changes made to a Deployment for audit or rollback purposes.                          |
| `k rollout undo`                     | Roll back to a previous version of a Deployment.                                             |

---

This example demonstrates how Kubernetes Deployments allow seamless updates (with rolling updates) and provide robust tools for monitoring and managing changes to your application.
