
### **Overview of External Connectivity in RHOCP**
In Kubernetes and RHOCP, applications running in **pods** are typically internal to the cluster, accessible via **services** (e.g., ClusterIP). To make these applications accessible from **outside the cluster** (e.g., over the internet), you need mechanisms to route external traffic to the appropriate pods. RHOCP provides two key resources for this:

1. **Routes**: An RHOCP-specific resource for exposing services to external clients, offering advanced features like TLS termination and traffic splitting.
2. **Ingress**: A standard Kubernetes resource for managing external HTTP/HTTPS traffic, with some limitations compared to Routes.

Both rely on an **Ingress Controller** (a reverse proxy) to handle incoming traffic and forward it to the correct services and pods.

---

### **Routes in RHOCP**
A **Route** is an RHOCP resource that exposes a **service** to external clients by assigning a publicly accessible **hostname**. Routes are managed by the **OpenShift Ingress Operator**, which deploys an **Ingress Controller** (typically based on HAProxy, called the OpenShift Router). The Router listens for external requests and directs them to the appropriate pods via the service.

#### **How Routes Work**
- **Hostname**: A Route is associated with a hostname (e.g., `api.apps.acme.com`), which must be a subdomain of the cluster’s **wildcard domain** (e.g., `*.apps.acme.com`). The wildcard domain is configured in the cluster’s DNS to resolve to the Router’s IP.
- **Service Mapping**: The Route points to a **service**, which in turn selects pods based on **labels**. For example, a Route might target a service named `api-frontend` that selects pods labeled `app=api`.
- **Port Mapping**: The Route specifies a **target port** on the service, which maps to a container port on the pods (e.g., Route port `80` to pod port `8080`).
- **TLS Support**: Routes support different TLS strategies:
  - **Edge Termination**: TLS terminates at the Router, and traffic to pods is unencrypted (HTTP).
  - **Passthrough**: TLS is forwarded to the pods, which handle decryption.
  - **Re-encryption**: TLS terminates at the Router and is re-encrypted before reaching the pods.
- **Path-Based Routing**: Routes can route traffic based on URL paths (e.g., `/api` to one service, `/web` to another).
- **Advanced Features**: Routes support traffic splitting (e.g., for blue-green deployments), sticky sessions, and wildcard subdomains.

#### **Creating a Route**
Use the `oc expose` command to create a Route from a service:

```bash
oc expose service api-frontend --hostname api.apps.acme.com
```

- **`api-frontend`**: The service to expose.
- **`--hostname`**: Specifies a custom hostname. If omitted, RHOCP generates one like `<route-name>-<namespace>.<wildcard-domain>` (e.g., `frontend-api.apps.acme.com`).

Example Route YAML:

```yaml
kind: Route
apiVersion: route.openshift.io/v1
metadata:
  name: a-simple-route
  labels:
    app: API
spec:
  host: api.apps.acme.com
  to:
    kind: Service
    name: api-frontend
  port:
    targetPort: 8443
```

- **`name`**: Unique name for the Route.
- **`host`**: The external hostname (a subdomain of the wildcard domain).
- **`to`**: Specifies the target service (`api-frontend`).
- **`targetPort`**: The port on the pods (mapped via the service).

#### **Key Notes**
- The cluster’s **DNS server** resolves the wildcard domain (e.g., `*.apps.acme.com`) to the Router’s IP. The Router then matches the requested hostname to a Route.
- If a hostname doesn’t match any Route, the Router returns an **HTTP 503** error.
- Routes are more feature-rich than Kubernetes Ingress, especially for TLS handling and traffic management.

#### **Deleting a Route**
Remove a Route with:

```bash
oc delete route a-simple-route
```

---

### **Ingress in Kubernetes and RHOCP**
An **Ingress** is a standard Kubernetes resource for managing external HTTP/HTTPS traffic. It defines rules for routing requests based on hostnames and paths, relying on an **Ingress Controller** to process them. In RHOCP, the **OpenShift Ingress Operator** provides the default Ingress Controller, but third-party controllers (e.g., NGINX, Traefik) can also be used.

#### **How Ingress Works**
- **Rules**: An Ingress object specifies rules for routing traffic, such as mapping a hostname (e.g., `www.example.com`) or path (e.g., `/api`) to a **service**.
- **Service Mapping**: The Ingress points to a service, which selects pods via labels.
- **TLS Support**: Ingress supports TLS termination using a **Secret** containing a certificate and key. Unlike Routes, it doesn’t natively support passthrough or re-encryption without controller-specific extensions.
- **Ingress Controller**: The controller (e.g., OpenShift Router) interprets the Ingress rules and configures the underlying proxy (e.g., HAProxy).

#### **Creating an Ingress**
Use the `oc create ingress` command:

```bash
oc create ingress ingr-sakila --rule="ingr-sakila.apps.ocp4.example.com/*=sakila-service:8080"
```

- **`ingr-sakila`**: Name of the Ingress.
- **`--rule`**: Specifies the routing rule (hostname, path, service, and port).

Example Ingress YAML:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend
spec:
  rules:
  - host: www.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 8080
```

- **`name`**: Unique name for the Ingress.
- **`host`**: The hostname for routing.
- **`paths`**: Maps paths (e.g., `/`) to a service (`frontend`) and port (`8080`).

#### **Key Notes**
- In RHOCP, when you create an Ingress object, the OpenShift Ingress Operator may automatically create a corresponding **Route** to handle the traffic, ensuring compatibility.
- Ingress is more portable across Kubernetes distributions but lacks some advanced features of Routes (e.g., traffic splitting, passthrough TLS).
- Ingress relies heavily on the Ingress Controller for features like TLS termination, path rewriting, or sticky sessions, which aren’t standardized.

---

### **Routes vs. Ingress**
Here’s a technical comparison:

| **Feature**               | **Route (RHOCP)**                              | **Ingress (Kubernetes/RHOCP)**               |
|---------------------------|-----------------------------------------------|---------------------------------------------|
| **Scope**                 | RHOCP-specific                                | Standard Kubernetes resource                |
| **Hostname**              | Subdomain of cluster wildcard domain          | Any hostname (depends on DNS setup)         |
| **TLS Options**           | Edge, Passthrough, Re-encryption              | Edge termination (controller-dependent)     |
| **Traffic Splitting**     | Supported (e.g., blue-green deployments)      | Not standard (controller-specific)          |
| **Path-Based Routing**    | Supported                                     | Supported                                   |
| **Integration**           | Native to OpenShift Router                    | Depends on Ingress Controller               |
| **Advanced Features**     | Sticky sessions, wildcard subdomains          | Controller-dependent (less standardized)    |
| **RHOCP Behavior**        | Primary method for external access            | May generate a managed Route                |

**Recommendation**: In RHOCP, **Routes** are preferred for external connectivity due to their rich feature set and native integration with the OpenShift Router. Use **Ingress** when portability across Kubernetes clusters is critical or when ecosystem tools specifically require Ingress.

---

### **How It All Fits Together**
1. **Pods**: Run your application containers (e.g., a web app listening on port `8080`).
2. **Service**: A ClusterIP service (e.g., `frontend-service`) selects pods via labels (e.g., `app=frontend`) and exposes an internal port (e.g., `8080`).
3. **Route/Ingress**:
   - A **Route** exposes the service externally with a hostname (e.g., `frontend.apps.acme.com`), mapping external port `80` or `443` to the service’s port.
   - An **Ingress** defines similar rules but relies on the Ingress Controller to route traffic.
4. **OpenShift Router**: The Ingress Controller (HAProxy-based) listens on the cluster’s external IP, matches incoming requests to Routes (or Ingress rules), and forwards traffic to the service’s pods.
5. **DNS**: The cluster’s wildcard domain (e.g., `*.apps.acme.com`) resolves to the Router’s IP. External clients use the Route’s hostname to access the app.

---

### **Example Workflow**
Suppose you have a web app:
- **Deployment**: `frontend` with pods labeled `app=frontend`, listening on port `8080`.
- **Service**: `frontend-service` with ClusterIP `172.30.1.1`, selecting `app=frontend`, exposing port `8080`.
- **Route**:
  ```bash
  oc expose service frontend-service --hostname frontend.apps.acme.com
  ```
  Creates a Route with hostname `frontend.apps.acme.com`, routing HTTP traffic to `frontend-service:8080`.
- **Ingress** (alternative):
  ```bash
  oc create ingress frontend --rule="frontend.apps.acme.com/*=frontend-service:8080"
  ```
  Creates an Ingress routing `frontend.apps.acme.com` to `frontend-service:8080`.
- **External Access**: A user visits `https://frontend.apps.acme.com`. The DNS resolves to the Router’s IP, the Router matches the hostname to the Route (or Ingress), and traffic is forwarded to a pod via `frontend-service`.

---

### **Key Commands**
- **Create Route**:
  ```bash
  oc expose service myapp-service --hostname myapp.apps.acme.com
  ```
- **View Routes**:
  ```bash
  oc get route
  ```
- **Delete Route**:
  ```bash
  oc delete route myapp-route
  ```
- **Create Ingress**:
  ```bash
  oc create ingress myapp --rule="myapp.apps.acme.com/*=myapp-service:8080"
  ```
- **View Ingress**:
  ```bash
  oc get ingress
  ```

---

### **Why This Matters**
- **Routes** provide a robust, RHOCP-native way to expose applications with advanced features like TLS handling and traffic splitting, ideal for production workloads.
- **Ingress** offers portability but may require additional configuration for advanced use cases.
- Both ensure your applications are accessible externally while maintaining the internal stability of services and pods.

In summary, **Routes** are the go-to choice in RHOCP for exposing services externally due to their flexibility and integration with the OpenShift Router. **Ingress** is a fallback for Kubernetes compatibility or specific use cases, with RHOCP bridging the gap by auto-generating Routes when needed.
