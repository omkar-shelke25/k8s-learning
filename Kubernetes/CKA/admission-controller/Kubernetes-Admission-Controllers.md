# **Kubernetes Admission Controllers: Comprehensive Notes**

## **1. Kubernetes Request Flow with kubectl**
The Kubernetes request pipeline processes API requests initiated by a user through `kubectl`. Below is the detailed flow, including built-in admission controllers and webhooks:

1. **User Initiates Request with kubectl**:
   - The user runs a command, e.g., `kubectl create pod my-pod --namespace dev --image nginx`.
   - `kubectl` constructs an HTTP API request and sends it to the Kubernetes **API server**.
   - The request includes credentials from the **KubeConfig** file (e.g., `~/.kube/config`), such as certificates or tokens.
   - Example KubeConfig:
     ```yaml
     apiVersion: v1
     kind: Config
     users:
     - name: developer-1
       user:
         client-certificate: /path/to/cert
         client-key: /path/to/key
     ```

2. **API Server Receives Request**:
   - The **API server**, the central control plane component, receives the request and processes it through several stages.

3. **Authentication**:
   - **Purpose**: Verify the identity of the user or service.
   - **Mechanism**: Uses credentials from the KubeConfig file (e.g., X.509 certificates, bearer tokens, or service account tokens).
   - **Process**:
     - The API server validates credentials against configured authentication methods.
     - If valid, the user is identified (e.g., “developer-1”).
     - If invalid, the request is rejected (e.g., “Unauthorized”).
   - **Example**: A certificate identifies the user as “developer-1”.

4. **Authorization**:
   - **Purpose**: Check if the authenticated user has permission to perform the requested action.
   - **Mechanism**: Uses **Role-Based Access Control (RBAC)** or other modules (RBAC is most common).
   - **Process**:
     - The API server checks the user’s permissions against **Roles** (namespace-scoped) or **ClusterRoles** (cluster-wide).
     - Permissions specify:
       - **Resources**: e.g., pods, services, deployments.
       - **Verbs**: e.g., `get`, `list`, `create`, `update`, `delete`.
       - **Scopes**: Namespaces or specific resource names.
     - Example RBAC Role:
       ```yaml
       apiVersion: rbac.authorization.k8s.io/v1
       kind: Role
       metadata:
         namespace: dev
         name: developer
       rules:
       - apiGroups: [""]
         resources: ["pods"]
         verbs: ["create", "get", "list", "update", "delete"]
         resourceNames: ["blue", "orange"]
       ```
     - **Outcome**: “developer-1” can create pods named “blue” or “orange” in the `dev` namespace but cannot modify services.

5. **Admission Control**:
   - **Purpose**: Enforce policies or modify the request before persistence in the **etcd** database.
   - **Sub-Phases**:
     - **Mutating Admission Phase**:
       - **Built-in Mutating Admission Controllers**: Apply predefined modifications (e.g., `DefaultStorageClass` adds a default storage class to PVCs).
       - **Mutating Webhooks**: Custom modifications via external services (e.g., add labels, inject sidecars).
     - **Validating Admission Phase**:
       - **Built-in Validating Admission Controllers**: Enforce predefined policies (e.g., `NamespaceLifecycle` rejects requests to non-existent namespaces).
       - **Validating Webhooks**: Custom validations via external services (e.g., reject untrusted images).
   - **Process**:
     - The API server processes the request through a chain of enabled admission controllers.
     - **Mutating Phase**:
       - Built-in mutating controllers (e.g., `DefaultStorageClass`) apply changes first.
       - Mutating webhooks then apply custom modifications via JSON patches.
     - **Validating Phase**:
       - Built-in validating controllers (e.g., `NamespaceLifecycle`) validate the modified request.
       - Validating webhooks then enforce custom policies, approving or rejecting the request.
     - If any validating controller or webhook rejects, the request fails.
   - **Example**:
     - **Built-in Mutating**: `DefaultStorageClass` adds a storage class to a PVC.
     - **Mutating Webhook**: Adds resource limits to a pod.
     - **Built-in Validating**: `NamespaceLifecycle` ensures the namespace exists.
     - **Validating Webhook**: Rejects pods with images not from `mycompany.registry.com`.

6. **Persistence in etcd**:
   - If all admission controllers approve, the API server stores the resource configuration in the **etcd** database.
   - The resource (e.g., pod) is created in the cluster.

7. **Response to User**:
   - The API server returns a response to `kubectl`, indicating success (e.g., “pod/my-pod created”) or failure (e.g., “namespace dev not found”).

**Key Point**: The flow is: **User → kubectl → API Server → Authentication → Authorization → Built-in Mutating Controllers → Mutating Webhooks → Built-in Validating Controllers → Validating Webhooks → etcd → Resource Created**.

---

## **2. Role-Based Access Control (RBAC)**
- **Definition**: RBAC is Kubernetes’ primary authorization mechanism, controlling access to API operations based on roles assigned to users or service accounts.
- **How It Works**:
  - **Roles** (namespace-scoped) or **ClusterRoles** (cluster-wide) define permissions via **RoleBindings** or **ClusterRoleBindings**.
  - Rules specify:
    - **Resources**: e.g., pods, services, deployments.
    - **Verbs**: e.g., `get`, `list`, `create`, `update`, `delete`.
    - **Scopes**: Namespaces or specific resource names.
  - Example RoleBinding:
    ```yaml
    apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
      namespace: dev
      name: developer-binding
    subjects:
    - kind: User
      name: developer-1
      apiGroup: rbac.authorization.k8s.io
    roleRef:
      kind: Role
      name: developer
      apiGroup: rbac.authorization.k8s.io
    ```
  - **Outcome**: “developer-1” can manage pods in the `dev` namespace but not other resources or namespaces.
- **Limitations**:
  - RBAC operates at the **API level**, controlling **who** can perform **what** actions.
  - It cannot enforce resource content policies, such as:
    - Restricting images to a specific registry.
    - Preventing the `latest` tag.
    - Ensuring `runAsNonRoot: true`.
    - Requiring metadata labels.

**Key Point**: RBAC is limited to API-level access control, necessitating admission controllers for resource configuration enforcement.

---

## **3. Admission Controllers**
- **Definition**: Admission controllers are plugins in the Kubernetes API server that intercept requests **after authentication and authorization** but **before persistence** in `etcd`. They can:
  - **Validate**: Approve or reject based on policies.
  - **Mutate**: Modify resource configurations (e.g., add defaults).
  - **Perform Actions**: Execute backend operations (e.g., create namespaces).
- **Purpose**:
  - Enforce cluster-wide policies beyond RBAC.
  - Enhance security (e.g., restrict untrusted images).
  - Ensure consistency (e.g., add labels, set limits).
- **Types**:
  - **Built-in Admission Controllers**: Predefined controllers provided by Kubernetes (mutating and validating).
  - **Webhook-Based Admission Controllers**:
    - **Mutating Webhooks**: Custom modifications via external services.
    - **Validating Webhooks**: Custom validations via external services.
- **Examples of Policies**:
  - Built-in: Ensure namespaces exist (`NamespaceLifecycle`).
  - Webhook: Reject pods using `docker.io` images or add sidecar containers.

**Key Point**: Admission controllers complement RBAC by enforcing fine-grained resource policies.

---

## **4. Number of Built-in Admission Controllers**
As of Kubernetes 1.31 (latest as of July 2025, based on release cycles), Kubernetes provides **over 30 built-in admission controllers**, divided into **mutating** and **validating** types. The exact number may vary slightly by version, as new controllers are added and others deprecated. Below is a non-exhaustive list of commonly used built-in controllers, with their mutating or validating nature:

- **Mutating Built-in Controllers**:
  1. **DefaultStorageClass**: Adds a default storage class to PersistentVolumeClaims (PVCs) if unspecified.
  2. **DefaultTolerationSeconds**: Sets default toleration seconds for pods.
  3. **ServiceAccount**: Automates service account token management.
  4. **PodPreset**: Injects settings into pods based on PodPreset resources (deprecated in newer versions).
  5. **Priority**: Assigns a default priority class to pods if unspecified.

- **Validating Built-in Controllers**:
  6. **NamespaceLifecycle**: Rejects requests to non-existent namespaces and protects default namespaces (`default`, `kube-system`, `kube-public`).
  7. **LimitRanger**: Enforces resource limits and quotas.
  8. **ResourceQuota**: Enforces namespace resource quotas.
  9. **PodSecurity**: Enforces Pod Security Standards (e.g., restricted, baseline, privileged).
  10. **AlwaysPullImages**: Ensures images are pulled from the registry, preventing tampered local images.
  11. **EventRateLimit**: Limits API server request rates.
  12. **NodeRestriction**: Limits kubelet actions.
  ...and others like `CertificateApproval`, `ImagePolicyWebhook`, `ValidatingAdmissionPolicy`.

- **Default Enabled Controllers**: In a typical setup (e.g., `kubeadm`), around 10-15 controllers are enabled by default, such as `NamespaceLifecycle`, `LimitRanger`, `ServiceAccount`, and `PodSecurity`. The exact list depends on the Kubernetes version and cluster configuration.
- **Viewing Enabled Controllers**:
  ```bash
  kube-apiserver -h | grep enable-admission-plugins
  ```
  In a `kubeadm` setup:
  ```bash
  kubectl exec -n kube-system <kube-apiserver-pod> -- kube-apiserver -h | grep enable-admission-plugins
  ```
- **Enabling/Disabling**:
  - Modify `kube-apiserver` manifest (e.g., `/etc/kubernetes/manifests/kube-apiserver.yaml`):
    ```yaml
    spec:
      containers:
      - command:
        - kube-apiserver
        - --enable-admission-plugins=NamespaceLifecycle,LimitRanger,DefaultStorageClass
        - --disable-admission-plugins=NamespaceAutoProvision
    ```
  - Restart the API server to apply changes.

**Key Point**: Kubernetes 1.31 offers over 30 built-in admission controllers, with both mutating and validating types, and a subset enabled by default.

---

## **5. Mutating Admission Webhooks**
- **Definition**: Mutating webhooks are custom admission controllers that modify API requests by adding, changing, or removing fields. They are defined via `MutatingWebhookConfiguration`.
- **Purpose**:
  - **Defaulting**: Add default values (e.g., resource limits, labels).
  - **Enforcement**: Override fields (e.g., change image registry).
  - **Augmentation**: Add components (e.g., sidecar containers).
- **How They Work**:
  - The API server sends the request to an external webhook service (e.g., OPA, Kyverno).
  - The webhook returns a **JSON patch** to modify the resource.
  - Example:
    - Add resource limits to a pod:
      ```yaml
      resources:
        limits:
          cpu: "500m"
          memory: "512Mi"
      ```
- **Configuration Example**:
  ```yaml
  apiVersion: admission.k8s.io/v1
  kind: MutatingWebhookConfiguration
  webhooks:
  - name: add-defaults.example.com
    rules:
    - operations: ["CREATE"]
      apiGroups: [""]
      apiVersions: ["v1"]
      resources: ["pods"]
    namespaceSelector:
      matchLabels:
        env: dev
    admissionReviewVersions: ["v1"]
    clientConfig:
      service:
        name: webhook-service
        namespace: default
        path: /mutate
      caBundle: <base64-encoded-CA-cert>
    sideEffects: None
  ```
- **Use Case**:
  - Inject a `fluentd` sidecar for logging:
    ```yaml
    spec:
      containers:
      - name: main-app
        image: nginx
      - name: logging-sidecar
        image: fluentd:1.14
    ```

**Key Point**: Mutating webhooks run after built-in mutating controllers, applying custom modifications.

---

## **6. Validating Admission Webhooks**
- **Definition**: Validating webhooks evaluate API requests against custom policies and approve or reject them without modification. They are defined via `ValidatingWebhookConfiguration`.
- **Purpose**:
  - Enforce policies beyond RBAC (e.g., restrict untrusted images).
  - Ensure compliance with security or organizational standards.
- **How They Work**:
  - The API server sends the (potentially modified) request to a webhook service.
  - The webhook returns an `AdmissionReview` response with `allowed: true` or `false` and an optional rejection message.
  - Example (OPA Rego policy):
    ```rego
    package kubernetes.admission
    deny[msg] {
      input.request.kind.kind == "Pod"
      image := input.request.object.spec.containers[_].image
      not startswith(image, "mycompany.registry.com")
      msg := sprintf("Image %v is not allowed", [image])
    }
    ```
- **Configuration Example**:
  ```yaml
  apiVersion: admission.k8s.io/v1
  kind: ValidatingWebhookConfiguration
  webhooks:
  - name: restrict-images.example.com
    rules:
    - operations: ["CREATE", "UPDATE"]
      apiGroups: [""]
      apiVersions: ["v1"]
      resources: ["pods"]
    namespaceSelector:
      matchLabels:
        env: dev
    admissionReviewVersions: ["v1"]
    clientConfig:
      service:
        name: webhook-service
        namespace: default
        path: /validate
      caBundle: <base64-encoded-CA-cert>
    sideEffects: None
  ```
- **Multiple Validating Webhooks**:
  - The repetition of “validating webhook validating webhook” likely refers to multiple validating webhooks.
  - Kubernetes supports chaining multiple validating webhooks in a `ValidatingWebhookConfiguration`.
  - Each webhook must approve the request.
  - Example:
    - First webhook: Ensures images are from `mycompany.registry.com`.
    - Second webhook: Ensures `runAsNonRoot: true`.
    ```yaml
    apiVersion: admission.k8s.io/v1
    kind: ValidatingWebhookConfiguration
    webhooks:
    - name: restrict-registry.example.com
      rules:
      - operations: ["CREATE"]
        apiGroups: [""]
        apiVersions: ["v1"]
        resources: ["pods"]
      clientConfig:
        service:
          name: webhook-service
          namespace: default
          path: /validate-registry
    - name: enforce-nonroot.example.com
      rules:
      - operations: ["CREATE"]
        apiGroups: [""]
        apiVersions: ["v1"]
        resources: ["pods"]
      clientConfig:
        service:
          name: webhook-service
          namespace: default
          path: /validate-nonroot
    ```

**Key Point**: Validating webhooks run after built-in validating controllers, enforcing custom policies on the modified resource.

---

## **7. Practical Example**
- **Scenario**: In the `dev` namespace:
  - Built-in mutating controller: `DefaultTolerationSeconds` adds toleration seconds.
  - Mutating webhook: Adds resource limits to pods.
  - Built-in validating controller: `NamespaceLifecycle` ensures the namespace exists.
  - Validating webhooks: Ensure images are from `mycompany.registry.com` and `runAsNonRoot: true`.
- **Flow**:
  1. **User Command**:
     ```bash
     kubectl create pod test-pod --namespace dev --image docker.io/nginx
     ```
  2. **Authentication**: Verifies “developer-1” via certificate.
  3. **Authorization**: RBAC confirms “developer-1” can create pods in `dev`.
  4. **Mutating Phase**:
     - **Built-in Mutating Controller**: `DefaultTolerationSeconds` adds:
       ```yaml
       spec:
         tolerations:
         - key: "node.kubernetes.io/not-ready"
           operator: "Exists"
           effect: "NoExecute"
           tolerationSeconds: 300
       ```
     - **Mutating Webhook**:
       ```yaml
       apiVersion: admission.k8s.io/v1
       kind: MutatingWebhookConfiguration
       webhooks:
       - name: add-resource-limits.example.com
         rules:
         - operations: ["CREATE"]
           apiGroups: [""]
           apiVersions: ["v1"]
           resources: ["pods"]
         namespaceSelector:
           matchLabels:
             env: dev
         clientConfig:
           service:
             name: webhook-service
             namespace: default
             path: /mutate
       ```
       - **Action**: Adds:
         ```yaml
         resources:
           limits:
             cpu: "500m"
             memory: "512Mi"
         ```
  5. **Validating Phase**:
     - **Built-in Validating Controller**: `NamespaceLifecycle` confirms the `dev` namespace exists.
     - **Validating Webhooks**:
       ```yaml
       apiVersion: admission.k8s.io/v1
       kind: ValidatingWebhookConfiguration
       webhooks:
       - name: restrict-images.example.com
         rules:
         - operations: ["CREATE"]
           apiGroups: [""]
           apiVersions: ["v1"]
           resources: ["pods"]
         namespaceSelector:
           matchLabels:
             env: dev
         clientConfig:
           service:
             name: webhook-service
             namespace: default
             path: /validate-images
       - name: enforce-nonroot.example.com
         rules:
         - operations: ["CREATE"]
           apiGroups: [""]
           apiVersions: ["v1"]
           resources: ["pods"]
         namespaceSelector:
           matchLabels:
             env: dev
         clientConfig:
           service:
             name: webhook-service
             namespace: default
             path: /validate-nonroot
       ```
       - **Actions**:
         - First webhook: Rejects `docker.io/nginx`.
         - Second webhook: Checks `runAsNonRoot: true`.
       - **Result**: Request fails with “Images from docker.io are not allowed.”
  6. **Test Success Case**:
     ```bash
     kubectl create pod test-pod --namespace dev --image mycompany.registry.com/nginx:v1
     ```
     - **Mutating Phase**: `DefaultTolerationSeconds` adds tolerations; webhook adds resource limits.
     - **Validating Phase**: `NamespaceLifecycle` confirms namespace; webhooks approve if `runAsNonRoot: true`.
     - **Result**: Pod created with tolerations and resource limits.

**Key Point**: The example shows the full flow, including built-in and webhook-based controllers.

---

## **8. Diagram: Kubernetes Request Flow (Updated)**

**Textual Representation**:
```
[User] --> [kubectl] --> [API Server]
                              |
                              v
                        [Authentication]
                              |
                              v
                        [Authorization (RBAC)]
                              |
                              v
                        [Mutating Admission Phase]
                        |       |
                        v       v
                [Built-in Mutating Controllers] [Mutating Webhooks]
                        |       |
                        v       v
                    [Webhook Service] [Apply JSON Patch]
                              |
                              v
                        [Validating Admission Phase]
                        |       |
                        v       v
                [Built-in Validating Controllers] [Validating Webhooks]
                        |       |
                        v       v
                    [Webhook Service] [Approve/Reject]
                              |
                              v
                          [etcd Database]
                              |
                              v
                        [Resource Created]
```

**Explanation**:
1. **User → kubectl**: User runs a command, and `kubectl` sends an API request.
2. **API Server**: Receives the request.
3. **Authentication**: Verifies user identity via KubeConfig.
4. **Authorization (RBAC)**: Checks permissions.
5. **Mutating Admission Phase**:
   - **Built-in Mutating Controllers**: Apply predefined modifications (e.g., `DefaultStorageClass`).
   - **Mutating Webhooks**: Apply custom modifications (e.g., add labels).
6. **Validating Admission Phase**:
   - **Built-in Validating Controllers**: Enforce predefined policies (e.g., `NamespaceLifecycle`).
   - **Validating Webhooks**: Enforce custom policies (e.g., restrict images).
7. **etcd Database**: Persists the resource if approved.
8. **Resource Created**: Resource is created, and a response is sent to the user.

**Note**: Use a diagramming tool (e.g., draw.io) to create a visual flowchart.

---

## **9. Key Considerations**
- **Order of Execution**:
  - Mutating phase (built-in controllers, then webhooks) precedes validating phase (built-in controllers, then webhooks).
  - Multiple controllers/webhooks are executed in the order defined in configurations or API server flags.
- **Performance**:
  - Webhooks add latency due to external service calls.
  - Ensure webhook services are highly available and scalable.
- **Security**:
  - Use TLS (`caBundle`) for webhook communication.
  - Validate webhook service identity.
- **Error Handling**:
  - Mutating controller/webhook failure may bypass modifications or reject the request.
  - Any validating controller/webhook rejection fails the request.
- **Tools**:
  - **Open Policy Agent (OPA)**: Define policies in Rego for mutating/validating.
  - **Kyverno**: YAML-based policies for simplicity.
  - **Custom Webhooks**: For complex logic.
- **Configuration**:
  - Built-in controllers: Configured via `kube-apiserver` flags (`--enable-admission-plugins`, `--disable-admission-plugins`).
  - Webhooks: Configured via `MutatingWebhookConfiguration` and `ValidatingWebhookConfiguration`.

---

## **10. Key Takeaways**
- **Request Flow**: User → kubectl → API Server → Authentication → Authorization → Built-in Mutating Controllers → Mutating Webhooks → Built-in Validating Controllers → Validating Webhooks → etcd → Resource Created.
- **RBAC**: Controls API-level access, not resource content.
- **Admission Controllers**:
  - **Built-in**: Over 30 controllers (e.g., `NamespaceLifecycle`, `DefaultStorageClass`), with mutating and validating types.
  - **Webhooks**: Mutating (modify) and Validating (approve/reject).
- **Mutating Controllers/Webhooks**: Add defaults, enforce policies, or augment resources.
- **Validating Controllers/Webhooks**: Enforce policies (e.g., restrict images, `runAsNonRoot`).
- **Multiple Validating Webhooks**: Chain policies for layered enforcement.
- **Configuration**: Built-in via API server flags; webhooks via Kubernetes resources.

---


