### **1. Introduction to Admission Controllers**

**What are Admission Controllers?**
Admission Controllers in Kubernetes are plugins that intercept requests to the Kubernetes API server after authentication and authorization but before the requested object is persisted in the cluster. They serve as a gatekeeper to either validate (check if a request is valid) or mutate (modify the request) before allowing it to proceed.

- **Purpose**: Admission Controllers enforce policies, ensure compliance with cluster rules, or automatically modify resources to align with desired configurations.
- **Types**: There are two primary types of admission controllers:
  - **Validating Admission Controllers**: These check whether a request meets certain criteria and can either allow or deny it. They do not modify the request.
  - **Mutating Admission Controllers**: These modify the request before it is processed, adding or altering attributes of the resource being created or updated.
- **Hybrid Controllers**: Some admission controllers can perform both validation and mutation.

**How They Work**:
- Requests to the Kubernetes API server go through a sequence of steps: authentication (verifying the user), authorization (checking permissions), and then admission control.
- Admission controllers are invoked in a specific order:
  1. **Mutating controllers** are executed first to modify the request if needed.
  2. **Validating controllers** are executed afterward to ensure the modified (or unmodified) request complies with cluster policies.
- If any admission controller rejects the request, the entire request is denied, and an error is returned to the user.

---

### **2. Examples of Built-in Admission Controllers**

The lecture provides examples of two built-in admission controllers to illustrate the difference between validating and mutating controllers.

#### **Namespace Lifecycle (Validating Admission Controller)**

- **Function**: The `NamespaceLifecycle` admission controller validates whether a namespace exists before allowing a request to create or modify a resource in that namespace.
- **Behavior**: If a request references a non-existent namespace, the controller rejects it.
- **Example**: If a user tries to create a pod in a namespace called `my-namespace` but it doesn’t exist, the `NamespaceLifecycle` controller will deny the request.
- **Purpose**: Prevents operations on invalid namespaces, ensuring resources are only created in valid, pre-existing namespaces.

#### **Default Storage Class (Mutating Admission Controller)**

- **Function**: The `DefaultStorageClass` admission controller modifies requests to create Persistent Volume Claims (PVCs) by adding a default storage class if none is specified.
- **Behavior**:
  - When a PVC creation request is submitted without a storage class, this controller automatically adds the default storage class configured in the cluster.
  - The modified PVC is then persisted with the added storage class.
- **Example**: 
  - A user submits a PVC request without specifying a storage class.
  - The `DefaultStorageClass` controller checks the cluster for the default storage class (e.g., `standard`).
  - It modifies the PVC request to include `storageClassName: standard`.
  - When the user inspects the created PVC, they’ll see the `standard` storage class attached, even though they didn’t specify it.
- **Purpose**: Ensures PVCs always have a storage class, simplifying configuration for users and maintaining consistency in the cluster.

#### **Namespace Auto-Provisioning (Mutating Admission Controller)**

- **Function**: This controller automatically creates a namespace if it doesn’t exist when a resource is requested in that namespace.
- **Behavior**:
  - If a request references a non-existent namespace, the controller creates the namespace before allowing the request to proceed.
  - This is a mutating action because it alters the cluster state by creating a new namespace.
- **Example**:
  - A user submits a pod creation request in a namespace called `new-namespace` that doesn’t exist.
  - The `NamespaceAutoProvisioning` controller creates `new-namespace` and allows the pod creation to proceed.
- **Purpose**: Simplifies namespace management by automatically provisioning missing namespaces.

#### **Order of Execution**
- Mutating admission controllers (like `DefaultStorageClass` or `NamespaceAutoProvisioning`) are invoked **before** validating controllers (like `NamespaceLifecycle`).
- **Why?** If a mutating controller modifies the request (e.g., creates a namespace), the validating controller can then verify the modified request (e.g., confirm the namespace now exists).
- **Example Issue with Reverse Order**:
  - If `NamespaceLifecycle` (validating) ran before `NamespaceAutoProvisioning` (mutating), it would reject requests for non-existent namespaces, preventing the auto-provisioning controller from creating them.

---

### **3. Custom Admission Controllers: Webhooks**

For scenarios where built-in admission controllers don’t meet specific requirements, Kubernetes allows the creation of custom admission controllers using **webhooks**. These are external services that you deploy to handle custom validation or mutation logic.

#### **Types of Webhook Admission Controllers**
1. **Mutating Admission Webhook**:
   - Modifies the incoming request based on custom logic.
   - Example: Adding a specific label to every pod created in the cluster.
2. **Validating Admission Webhook**:
   - Validates the request and decides whether to allow or deny it.
   - Example: Rejecting pod creation if the pod name matches the username of the requester.

#### **How Webhooks Work**
- After a request passes through built-in admission controllers, it is sent to the configured webhook(s).
- The Kubernetes API server sends an **AdmissionReview** object (in JSON format) to the webhook server. This object contains:
  - Details about the request (e.g., user, operation type like `CREATE` or `UPDATE`, resource type like `Pod` or `Deployment`).
  - The object itself (e.g., the YAML/JSON definition of the pod or PVC).
- The webhook server processes the request, applies custom logic, and responds with an **AdmissionReview** object containing:
  - An `allowed` field (`true` to allow, `false` to deny).
  - For mutating webhooks, a `patch` field containing modifications to the object (e.g., a JSON patch to add labels).
- If the webhook rejects the request (`allowed: false`), the API server denies the request and returns an error to the user.

#### **Steps to Set Up a Custom Admission Webhook**

1. **Develop the Webhook Server**:
   - The webhook server is an API server that implements custom logic for validation or mutation.
   - **Requirements**:
     - Must accept HTTP POST requests at specific endpoints (e.g., `/mutate` for mutating, `/validate` for validating).
     - Must respond with a JSON-formatted `AdmissionReview` object.
   - **Languages**: Can be written in any language (e.g., Go, Python, Node.js), as long as it meets the API requirements.
   - **Example Logic**:
     - **Validation Example**: A validating webhook might reject a pod creation if the pod’s name matches the username of the requester (e.g., to prevent naming conflicts or enforce naming conventions).
     - **Mutation Example**: A mutating webhook might add a label like `created-by: <username>` to every pod created.
   - **Sample Pseudocode (Python)**:
     ```python
     from flask import Flask, request, jsonify
     app = Flask(__name__)

     @app.route('/validate', methods=['POST'])
     def validate():
         admission_review = request.get_json()
         request_obj = admission_review['request']
         user = request_obj['userInfo']['username']
         obj_name = request_obj['object']['metadata']['name']
         response = {
             'apiVersion': 'admission.k8s.io/v1',
             'kind': 'AdmissionReview',
             'response': {
                 'uid': request_obj['uid'],
                 'allowed': user != obj_name  # Reject if username equals object name
             }
         }
         return jsonify(response)

     @app.route('/mutate', methods=['POST'])
     def mutate():
         admission_review = request.get_json()
         request_obj = admission_review['request']
         user = request_obj['userInfo']['username']
         patch = [
             {
                 'op': 'add',
                 'path': '/metadata/labels/created-by',
                 'value': user
             }
         ]
         response = {
             'apiVersion': 'admission.k8s.io/v1',
             'kind': 'AdmissionReview',
             'response': {
                 'uid': request_obj['uid'],
                 'allowed': True,
                 'patchType': 'JSONPatch',
                 'patch': base64.b64encode(json.dumps(patch).encode()).decode()
             }
         }
         return jsonify(response)
     ```
     - **Validation Logic**: Rejects the request if the object’s name matches the username.
     - **Mutation Logic**: Adds a `created-by` label with the username to the object’s metadata using a JSON patch.
     - **JSON Patch**: A standard format for describing changes to a JSON object (e.g., `add`, `remove`, `replace`). In the example, it adds a label at the path `/metadata/labels/created-by`.

2. **Deploy the Webhook Server**:
   - The webhook server can be hosted:
     - **Externally**: As a standalone server outside the Kubernetes cluster.
     - **Internally**: As a containerized application (e.g., a Deployment) within the Kubernetes cluster, exposed via a Service.
   - **Internal Deployment Example**:
     - Deploy the webhook server as a Kubernetes Deployment.
     - Expose it using a Service (e.g., `webhook-service` in the `default` namespace).
     - Ensure the service is accessible over HTTPS (requires TLS certificates).

3. **Configure the Webhook in Kubernetes**:
   - Create a **ValidatingWebhookConfiguration** or **MutatingWebhookConfiguration** object to register the webhook with the Kubernetes API server.
   - **Example YAML (Validating Webhook)**:
     ```yaml
     apiVersion: admissionregistration.k8s.io/v1
     kind: ValidatingWebhookConfiguration
     metadata:
       name: podpolicy.example.com
     webhooks:
     - name: podpolicy.example.com
       clientConfig:
         service:
           namespace: default
           name: webhook-service
         caBundle: <base64-encoded-CA-certificate>
       rules:
       - operations: ["CREATE"]
         apiGroups: [""]
         apiVersions: ["v1"]
         resources: ["pods"]
       admissionReviewVersions: ["v1"]
       sideEffects: None
     ```
   - **Key Fields**:
     - `apiVersion` and `kind`: Specify `admissionregistration.k8s.io/v1` and either `ValidatingWebhookConfiguration` or `MutatingWebhookConfiguration`.
     - `metadata.name`: A unique name for the webhook configuration (e.g., `podpolicy.example.com`).
     - `webhooks`: A list of webhook definitions.
       - `name`: A unique name for the webhook (e.g., `podpolicy.example.com`).
       - `clientConfig`: Specifies how to reach the webhook server.
         - `service`: If the server is in the cluster, provide the namespace and service name (e.g., `webhook-service` in `default`).
         - `url`: If the server is external, provide the URL (e.g., `https://webhook.example.com`).
         - `caBundle`: A base64-encoded CA certificate for TLS communication.
       - `rules`: Define when the webhook is invoked.
         - `operations`: The types of operations to intercept (e.g., `CREATE`, `UPDATE`, `DELETE`).
         - `apiGroups`: The API group of the resource (e.g., `""` for core resources like pods).
         - `apiVersions`: The API version (e.g., `v1`).
         - `resources`: The resource types (e.g., `pods`, `deployments`).
       - `admissionReviewVersions`: The versions of the `AdmissionReview` object the webhook supports (e.g., `v1`).
       - `sideEffects`: Indicates whether the webhook has side effects (e.g., `None` for no side effects).

4. **TLS Configuration**:
   - The communication between the Kubernetes API server and the webhook server must use HTTPS.
   - **Steps**:
     - Generate a TLS certificate and key for the webhook server.
     - Create a CA bundle to validate the server’s certificate.
     - Include the base64-encoded CA bundle in the `clientConfig.caBundle` field of the webhook configuration.
   - **Why TLS?** Ensures secure communication and prevents man-in-the-middle attacks.

5. **Testing the Webhook**:
   - Once the webhook server is deployed and the configuration is applied, Kubernetes will call the webhook for matching requests (e.g., pod creation).
   - The webhook processes the `AdmissionReview` request and responds with an `allowed` field and, for mutating webhooks, a `patch` field.
   - Example:
     - A user creates a pod.
     - The webhook server receives the request, adds a `created-by: <username>` label, and responds with `allowed: true` and the JSON patch.
     - The API server applies the patch and creates the pod with the added label.

---

### **4. Practical Considerations**

- **Built-in vs. Custom Admission Controllers**:
  - Built-in controllers (e.g., `NamespaceLifecycle`, `DefaultStorageClass`) are part of the Kubernetes source code and enabled by default or via configuration.
  - Custom webhooks allow organizations to enforce specific policies not covered by built-in controllers (e.g., rejecting pods with certain annotations, enforcing resource quotas, or adding custom metadata).
- **Performance**:
  - Webhooks introduce latency because they require an external HTTP call.
  - Ensure the webhook server is highly available and responsive to avoid delays in API requests.
- **Security**:
  - Use TLS to secure communication.
  - Restrict webhook permissions to specific operations and resources to minimize security risks.
- **Testing and Debugging**:
  - Test webhooks in a non-production environment to avoid disrupting the cluster.
  - Log webhook requests and responses for debugging.
- **Exam Note**:
  - As mentioned in the lecture, certification exams (e.g., CKA, CKAD) typically don’t require writing webhook code but may test understanding of how to configure and use webhooks.

---

### **5. Example Use Cases**

- **Validation**:
  - Enforce naming conventions (e.g., reject pods with names not following a specific pattern).
  - Prevent certain users from creating resources in specific namespaces.
- **Mutation**:
  - Automatically add labels or annotations to resources (e.g., `environment: production`).
  - Inject sidecar containers (e.g., for logging or monitoring) into pods.
- **Hybrid**:
  - Add a default resource limit to pods (mutation) and reject pods exceeding a certain CPU/memory threshold (validation).

---

### **6. Summary**

- **Admission Controllers**: Plugins that validate or mutate API requests before persistence.
- **Types**:
  - **Validating**: Check requests and allow/deny (e.g., `ម

System: **NamespaceLifecycle**).
  - **Mutating**: Modify requests (e.g., **DefaultStorageClass**, **NamespaceAutoProvisioning**).
- **Order**: Mutating controllers run before validating controllers to ensure modifications are validated.
- **Custom Webhooks**:
  - **MutatingWebhookConfiguration** and **ValidatingWebhookConfiguration** allow custom logic.
  - Involve deploying a webhook server and configuring Kubernetes to call it.
  - Use `AdmissionReview` objects for communication, with JSON patches for mutations.
- **Setup**:
  - Develop and deploy a webhook server (e.g., in Go or Python).
  - Configure a webhook object with rules, client config, and TLS certificates.
  - Test thoroughly to ensure correct behavior.

