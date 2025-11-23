
Let me break down the **complete communication flow** when a CI/CD service account token is used:

## Full Communication Flow Diagram

```
CI/CD System                API Server              Controller Manager
     |                           |                           |
     |  1. Request with token    |                           |
     |-------------------------->|                           |
     |  Authorization: Bearer    |                           |
     |  eyJhbGc...               |                           |
     |                           |                           |
     |                      2. Extract JWT                   |
     |                      from Bearer token                |
     |                           |                           |
     |                      3. Verify signature              |
     |                      using sa.pub                     |
     |                           |                           |
     |                      4. Extract identity              |
     |                      (SA name, namespace)             |
     |                           |                           |
     |                      5. RBAC Authorization            |
     |                      Check permissions                |
     |                           |                           |
     |                      6. Execute request               |
     |                      (if authorized)                  |
     |                           |                           |
     |  7. Return response       |                           |
     |<--------------------------|                           |
     |  (pods list, status, etc) |                           |
```

## Detailed Step-by-Step Flow

### **Phase 1: Token Creation (One-time setup)**

```
Controller Manager:
1. Generates JWT token
2. Signs with sa.key (private key)
3. Includes claims:
   - iss: kubernetes/serviceaccount
   - sub: system:serviceaccount:namespace:sa-name
   - exp: expiration timestamp
```

### **Phase 2: Token Storage**

```
CI/CD System:
- Stores token securely (env var, secret manager, CI/CD vault)
- Token looks like: eyJhbGciOiJSUzI1NiIsImtpZCI6...
```

### **Phase 3: API Request**

```
CI/CD -> API Server:

HTTPS Request:
POST https://k8s-api-server:6443/api/v1/namespaces/default/pods
Headers:
  Authorization: Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6...
  Content-Type: application/json
Body:
  { "apiVersion": "v1", "kind": "Pod", ... }
```

### **Phase 4: API Server Processing**

```
API Server receives request:

Step 1: TLS Handshake
  - Validates client's TLS connection
  - Uses API server certificate (signed by cluster CA)

Step 2: Authentication
  - Extracts token from Authorization header
  - Identifies token as JWT (Bearer)
  - Decodes JWT header and payload
  - Verifies signature using sa.pub
  - Checks token expiration
  - Extracts user identity: system:serviceaccount:default:cicd-sa

Step 3: Authorization (RBAC)
  - Looks up RoleBindings/ClusterRoleBindings for cicd-sa
  - Checks if action is permitted:
    * Resource: pods
    * Verb: create
    * Namespace: default
  - Decision: Allow or Deny

Step 4: Admission Control
  - Runs admission controllers (validating, mutating webhooks)
  - Applies security policies, resource quotas, etc.

Step 5: Persistence
  - Writes to etcd (encrypted at rest)
  - Returns response to client
```

### **Phase 5: Response**

```
API Server -> CI/CD:

HTTP 201 Created
Body:
{
  "kind": "Pod",
  "metadata": {
    "name": "app-pod",
    "namespace": "default",
    ...
  },
  "status": "Pending"
}
```

## Network Path Detail

```
CI/CD Server                      Kubernetes Cluster
     |                                    |
     |  [Internet/VPN]                    |
     |-------------------------------->   |
     |  HTTPS (443 or 6443)               |
     |                                    |
     |                            Load Balancer (if any)
     |                                    |
     |                            API Server (kube-apiserver)
     |                                    |
     |                            - Authentication
     |                            - Authorization  
     |                            - Admission
     |                                    |
     |                            etcd cluster
     |                            (data storage)
```

## Authentication Methods Comparison

```
Token Authentication (what you're using):
CI/CD --[Bearer Token]--> API Server --[Verify with sa.pub]

vs

Certificate Authentication:
CI/CD --[Client Cert]--> API Server --[Verify with ca.crt]

vs

OIDC Authentication:
CI/CD --[ID Token]--> API Server --[Verify with external OIDC provider]
```

## Token Validation Deep Dive

```
JWT Token Structure:
Header:  { "alg": "RS256", "typ": "JWT" }
Payload: { 
  "iss": "kubernetes/serviceaccount",
  "sub": "system:serviceaccount:default:cicd-sa",
  "exp": 1735689600,
  "iat": 1704153600,
  "kubernetes.io": {
    "namespace": "default",
    "serviceaccount": {
      "name": "cicd-sa",
      "uid": "abc-123-def"
    }
  }
}
Signature: [signed with sa.key, verified with sa.pub]
```

## Security Layers in Communication

1. **Transport Security**: TLS encryption (API server certificate)
2. **Authentication**: Token signature verification (sa.pub)
3. **Authorization**: RBAC policy enforcement
4. **Admission**: Policy webhooks and validation
5. **Audit**: All requests logged for compliance

## Common Communication Patterns

**Pattern 1: Deploy Application**
```
CI/CD sends:
1. kubectl apply -f deployment.yaml
2. Token authenticates
3. RBAC checks "create deployments" permission
4. Admission controllers validate
5. Deployment created
```

**Pattern 2: Check Status**
```
CI/CD sends:
1. kubectl get pods
2. Token authenticates  
3. RBAC checks "list pods" permission
4. Returns pod list
```

**Pattern 3: Update Secret**
```
CI/CD sends:
1. kubectl create secret
2. Token authenticates
3. RBAC checks "create secrets" permission
4. Secret stored in etcd (encrypted)
```

Would you like me to explain any specific part in more detail, such as RBAC configuration, token expiration handling, or troubleshooting authentication issues?
