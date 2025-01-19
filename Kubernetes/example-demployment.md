## Deep Notes on Kubernetes Deployment and Rollout Management

This document provides a detailed explanation of Kubernetes Deployment, the associated YAML structure, and the commands used for managing deployments, rollouts, and rollbacks.

---

### **1. Deployment YAML Deep Dive**

#### **Definition**
A Kubernetes Deployment is a higher-level abstraction that manages ReplicaSets and Pods. It ensures a specified number of Pods are running and provides mechanisms for updating applications seamlessly.

#### **Example YAML**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: testing
  labels:
    app: web
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 25%
  replicas: 10
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      name: template-testing
      labels:
        app: web
    spec:
      containers:
        - name: nginx-web
          image: nginx
```

#### **Key Sections**

1. **`apiVersion`**: Specifies the API version to use (apps/v1 is for Deployments).
2. **`kind`**: Specifies the resource type as `Deployment`.
3. **`metadata`**:
   - **`name`**: The name of the deployment, here `testing`.
   - **`labels`**: Key-value pairs for categorizing resources.
4. **`spec`**:
   - **`strategy`**:
     - **`type: RollingUpdate`**: Specifies that updates should be applied gradually.
     - **`maxUnavailable: 25%`**: Ensures a maximum of 25% of Pods are unavailable during updates.
     - **`maxSurge: 25%`**: Allows up to 25% additional Pods during updates.
   - **`replicas`**: Defines the desired number of Pods (10).
   - **`selector`**: Identifies Pods to manage, matching the label `app: web`.
   - **`template`**: Specifies the Pod definition:
     - **`metadata`**: Labels the Pod with `app: web`.
     - **`spec`**: Configures the container:
       - **`name`**: Name of the container (`nginx-web`).
       - **`image`**: Container image to use (`nginx`).

---

### **2. Managing Deployments with kubectl Commands**

Kubernetes provides powerful `kubectl` commands for working with Deployments, ReplicaSets, and Pods. Below are key commands and their detailed explanations.

#### **Command: Viewing Resources**
1. **List Deployments**
   ```bash
   kubectl get deploy
   ```
   - Displays information about current deployments, including desired, current, and available replicas.

2. **List ReplicaSets**
   ```bash
   kubectl get rs
   ```
   - Shows ReplicaSets created by the Deployment and their status.

3. **List Pods**
   ```bash
   kubectl get po
   ```
   - Lists all Pods in the namespace, showing their status (e.g., Running, Pending).

---

#### **Command: Updating a Deployment**
1. **Update Container Image**
   ```bash
   kubectl set image deploy/testing nginx-web=nginx:1.12 --record
   ```
   - Updates the `nginx-web` container to use the `nginx:1.12` image.
   - **`--record`**: Records the change in the Deployment's revision history.

2. **Monitor Rollout Status**
   ```bash
   kubectl rollout status deploy/testing
   ```
   - Checks the rollout's progress and ensures no errors occurred.

---

#### **Command: Managing Rollouts**
1. **View Rollout History**
   ```bash
   kubectl rollout history deploy/testing
   ```
   - Displays all revisions of the Deployment, including changes made to the container image or replicas.

2. **Rollback to a Previous Revision**
   ```bash
   kubectl rollout undo deploy/testing --to-revision=1
   ```
   - Rolls back the Deployment to revision 1. This is useful if the latest changes caused issues.

---

### **3. Use Cases of Commands**

| **Command**                              | **Use Case**                                                                                   |
|------------------------------------------|-----------------------------------------------------------------------------------------------|
| `kubectl get deploy`                     | View current deployments, their desired and available state.                                  |
| `kubectl get rs`                         | Monitor ReplicaSets associated with a deployment.                                             |
| `kubectl get po`                         | Check the status of Pods and identify potential issues.                                       |
| `kubectl set image`                      | Update the application image in a Deployment for rolling updates.                            |
| `kubectl rollout status`                 | Ensure the Deployment rollout proceeds smoothly.                                              |
| `kubectl rollout history`                | Review changes made to a Deployment, enabling better tracking of updates.                    |
| `kubectl rollout undo`                   | Roll back to a previous state if a deployment causes instability or downtime.                |

---

### **4. Detailed Workflow**

#### **Step 1: Create a Deployment**
- Write the Deployment YAML and apply it using:
  ```bash
  kubectl apply -f deployment.yaml
  ```

#### **Step 2: Verify the Deployment**
- Check if the Deployment, ReplicaSets, and Pods are running:
  ```bash
  kubectl get deploy
  kubectl get rs
  kubectl get po
  ```

#### **Step 3: Perform Updates**
- Update the container image:
  ```bash
  kubectl set image deploy/testing nginx-web=nginx:1.12 --record
  ```
- Monitor rollout status:
  ```bash
  kubectl rollout status deploy/testing
  ```

#### **Step 4: Manage Rollbacks**
- Check rollout history:
  ```bash
  kubectl rollout history deploy/testing
  ```
- Roll back to a stable revision:
  ```bash
  kubectl rollout undo deploy/testing --to-revision=1
  ```

---

### **5. Best Practices**
1. Always use versioned container images (e.g., `nginx:1.12`) to avoid unpredictable updates.
2. Use the `--record` flag during updates to maintain a clear revision history.
3. Monitor rollouts closely using `kubectl rollout status`.
4. Test updates in a staging environment before deploying to production.
5. Use health probes (liveness and readiness) in the Pod spec to ensure application stability during updates.

---

