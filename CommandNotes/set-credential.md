
### **What is `kubectl config set-credentials`?**

The `kubectl config set-credentials` command creates or updates a user entry in the kubeconfig file. A user entry defines how `kubectl` authenticates to a Kubernetes cluster for a specific identity (e.g., an admin, a developer, or a service account). The kubeconfig file can store multiple user entries, each identified by a unique name.

The command allows you to specify one or more authentication methods for the user, including:

1. **Client certificate-based authentication**:
   - Uses a client certificate (`--client-certificate`) and a private key (`--client-key`) to authenticate.
   - Optionally, you can embed the certificate and key data directly in the kubeconfig file using `--embed-certs=true`.

2. **Bearer token authentication**:
   - Uses a bearer token (`--token`) for authentication, commonly used with service accounts or OAuth-based authentication.

3. **Basic authentication**:
   - Uses a username (`--username`) and password (`--password`) for authentication.

**Note**: Bearer token and basic authentication are mutually exclusive—you cannot specify both for the same user entry.

When you run `kubectl config set-credentials`, it modifies the `users` section of the kubeconfig file. If the user entry already exists, the command merges the new values with the existing ones, preserving fields that aren’t overwritten. If the user entry doesn’t exist, it creates a new one.

---

### **Synopsis**

The command’s syntax is:

```bash
kubectl config set-credentials NAME \
  [--client-certificate=path/to/certfile] \
  [--client-key=path/to/keyfile] \
  [--token=bearer_token] \
  [--username=basic_user] \
  [--password=basic_password] \
  [--embed-certs=true|false]
```

- **`NAME`**: The name of the user entry in the kubeconfig file (e.g., `cluster-admin`, `developer`).
- **`--client-certificate`**: Path to the client certificate file (e.g., a `.crt` file).
- **`--client-key`**: Path to the client private key file (e.g., a `.key` file).
- **`--embed-certs`**: If set to `true`, embeds the certificate and key data directly in the kubeconfig file instead of referencing their file paths.
- **`--token`**: A bearer token for authentication.
- **`--username`**: Username for basic authentication.
- **`--password`**: Password for basic authentication.

---

### **How It Works**

The kubeconfig file is a YAML file with three main sections:

1. **clusters**: Defines the Kubernetes clusters (e.g., their API server URLs and CA certificates).
2. **users**: Defines user authentication details (e.g., certificates, tokens, or basic auth credentials).
3. **contexts**: Links a user and a cluster together, optionally with a namespace, to define a specific configuration for `kubectl`.

The `kubectl config set-credentials` command modifies the `users` section. For example, running:

```bash
kubectl config set-credentials cluster-admin --username=admin --password=secret
```

would add or update a user entry named `cluster-admin` in the kubeconfig file with basic authentication credentials.

Here’s what a kubeconfig file might look like after running the above command:

```yaml
apiVersion: v1
kind: Config
users:
- name: cluster-admin
  user:
    username: admin
    password: secret
clusters: []
contexts: []
current-context: ""
```

If you later run:

```bash
kubectl config set-credentials cluster-admin --token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

The command will overwrite the authentication method for `cluster-admin`, replacing the basic auth credentials with the token, resulting in:

```yaml
apiVersion: v1
kind: Config
users:
- name: cluster-admin
  user:
    token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
clusters: []
contexts: []
current-context: ""
```

This merge behavior ensures you can update specific fields without losing others, unless they conflict (e.g., token vs. basic auth).

---

### **Options Explained**

- **`--client-certificate`**: Specifies the path to a client certificate file (usually a `.crt` or `.pem` file) used for TLS-based authentication. This is typically issued by the cluster’s Certificate Authority (CA).
- **`--client-key`**: Specifies the path to the private key file (usually a `.key` file) corresponding to the client certificate.
- **`--embed-certs`**: If set to `true`, the certificate and key data are embedded as base64-encoded strings in the kubeconfig file. This makes the kubeconfig portable but increases its size and exposes sensitive data if not handled securely.
- **`--token`**: Specifies a bearer token, often used for service accounts or OAuth-based authentication. Tokens are sent in the `Authorization: Bearer` header.
- **`--username`**: Specifies the username for basic authentication. This is less secure and rarely used in modern Kubernetes setups.
- **`--password`**: Specifies the password for basic authentication, paired with `--username`.

---

### **Examples with Explanations**

Let’s explore practical examples to demonstrate how `kubectl config set-credentials` is used in different scenarios.

#### **Example 1: Setting Client Certificate Authentication**

Suppose you have a client certificate (`admin.crt`) and private key (`admin.key`) for a user named `cluster-admin`. You want to configure these in the kubeconfig file.

Run:

```bash
kubectl config set-credentials cluster-admin \
  --client-certificate=~/certs/admin.crt \
  --client-key=~/certs/admin.key
```

This updates the kubeconfig file to include:

```yaml
users:
- name: cluster-admin
  user:
    client-certificate: /home/user/certs/admin.crt
    client-key: /home/user/certs/admin.key
```

Here, the kubeconfig references the certificate and key files on disk. When `kubectl` authenticates, it reads these files to present the client certificate to the Kubernetes API server.

#### **Example 2: Embedding Certificate Data**

If you want to make the kubeconfig file portable (e.g., to use it on another machine without copying the certificate files), you can embed the certificate and key data.

Run:

```bash
kubectl config set-credentials cluster-admin \
  --client-certificate=~/certs/admin.crt \
  --client-key=~/certs/admin.key \
  --embed-certs=true
```

This results in:

```yaml
users:
- name: cluster-admin
  user:
    client-certificate-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUR...
    client-key-data: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQo...
```

The `client-certificate-data` and `client-key-data` fields contain base64-encoded versions of the certificate and key, respectively. This eliminates the need to reference external files, but be cautious as the kubeconfig now contains sensitive data.

#### **Example 3: Setting Basic Authentication**

For a legacy system that uses basic authentication, you can configure a user with a username and password.

Run:

```bash
kubectl config set-credentials developer \
  --username=devuser \
  --password=supersecret
```

This updates the kubeconfig file to:

```yaml
users:
- name: developer
  user:
    username: devuser
    password: supersecret
```

When `kubectl` authenticates as `developer`, it sends the username and password in the `Authorization: Basic` header. Note that basic authentication is insecure unless used over HTTPS and is deprecated in favor of tokens or certificates.

#### **Example 4: Setting Bearer Token Authentication**

Bearer tokens are commonly used with service accounts. Suppose you have a service account token for a user named `service-account`.

Run:

```bash
kubectl config set-credentials service-account \
  --token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

This updates the kubeconfig file to:

```yaml
users:
- name: service-account
  user:
    token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

When `kubectl` authenticates as `service-account`, it includes the token in the `Authorization: Bearer` header. This is a common setup for automated systems or CI/CD pipelines.

#### **Example 5: Updating an Existing User**

Suppose the `cluster-admin` user already has a client certificate configured, but you want to add a client key without overwriting the certificate.

Run:

```bash
kubectl config set-credentials cluster-admin \
  --client-key=~/certs/new-admin.key
```

If the original kubeconfig was:

```yaml
users:
- name: cluster-admin
  user:
    client-certificate: /home/user/certs/admin.crt
```

It becomes:

```yaml
users:
- name: cluster-admin
  user:
    client-certificate: /home/user/certs/admin.crt
    client-key: /home/user/certs/new-admin.key
```

The command merges the new `client-key` field without affecting the existing `client-certificate`.

#### **Example 6: Real-World Scenario – Service Account Setup**

Let’s say you’ve created a service account named `ci-bot` in the `default` namespace, and you want to configure `kubectl` to use its token for authentication.

1. Get the service account token:

   ```bash
   TOKEN=$(kubectl -n default get secret $(kubectl -n default get sa ci-bot -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 -d)
   ```

2. Configure the user in kubeconfig:

   ```bash
   kubectl config set-credentials ci-bot --token=$TOKEN
   ```

This adds:

```yaml
users:
- name: ci-bot
  user:
    token: <base64-decoded-token>
```

3. To use this user, you’d also need to define a cluster and context. For example:

   ```bash
   kubectl config set-cluster my-cluster --server=https://k8s.example.com --certificate-authority=~/certs/ca.crt
   kubectl config set-context ci-context --cluster=my-cluster --user=ci-bot --namespace=default
   kubectl config use-context ci-context
   ```

Now, `kubectl` commands will authenticate as the `ci-bot` service account.

---

### **Common Use Cases**

1. **Configuring Admin Access**: Use client certificates or tokens to set up an admin user for full cluster access.
2. **Service Account Authentication**: Configure tokens for automated systems like CI/CD pipelines.
3. **Multi-Cluster Management**: Define multiple user entries for different clusters in a single kubeconfig file.
4. **Portability**: Embed certificates for users who need to work across multiple machines.
5. **Legacy Systems**: Configure basic authentication for older Kubernetes setups (though this is rare).

---

### **Best Practices**

1. **Secure Your Kubeconfig**: The kubeconfig file contains sensitive data (tokens, certificates, keys). Restrict access with file permissions (e.g., `chmod 600 ~/.kube/config`).
2. **Use `--embed-certs` Sparingly**: Embedding certificates makes the kubeconfig portable but increases the risk of exposing sensitive data if the file is shared.
3. **Prefer Tokens or Certificates**: Basic authentication is insecure and deprecated. Use tokens (for service accounts) or certificates (for users) instead.
4. **Validate Changes**: After running `set-credentials`, use `kubectl config view` to verify the updated user entry.
5. **Backup Kubeconfig**: Before modifying, back up your kubeconfig file to avoid accidental overwrites.

---

### **Troubleshooting**

- **Error: "client-certificate and client-key must be specified together"**:
  - Ensure you provide both `--client-certificate` and `--client-key` when using certificate-based authentication.
- **Error: "token and username/password are mutually exclusive"**:
  - You cannot combine `--token` with `--username` or `--password`. Choose one authentication method.
- **Authentication Fails**:
  - Verify the certificate, key, or token is valid and matches the cluster’s expectations.
  - Check the cluster’s CA using `kubectl config set-cluster`.
- **Kubeconfig Not Updated**:
  - Ensure you have write permissions to `~/.kube/config` or the file specified by `$KUBECONFIG`.

---

### **Conclusion**

The `kubectl config set-credentials` command is a powerful tool for managing user authentication in Kubernetes. By allowing you to configure client certificates, bearer tokens, or basic authentication, it provides flexibility for various use cases, from admin access to service account automation. The command’s merge behavior ensures you can update specific fields without disrupting existing configurations, and options like `--embed-certs` add portability when needed.

The examples above cover common scenarios, but the command’s utility shines in complex environments with multiple clusters and users. Always follow security best practices, validate your changes, and prefer modern authentication methods like tokens or certificates over basic auth for production systems.

If you have a specific scenario or need help with a related `kubectl config` command, let me know!
