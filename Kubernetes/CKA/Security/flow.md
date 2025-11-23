# 🔐 Kubernetes mTLS Complete Deep Dive with Flow Diagrams

## 📋 Certificate Authority (CA) Hierarchy

```
KUBERNETES CLUSTER PKI STRUCTURE
═════════════════════════════════════════════════════════════

┌──────────────────────────────────────────────────────────┐
│  CLUSTER CA (Main Certificate Authority)                 │
│  Location: /etc/kubernetes/pki/                          │
│  ┌────────────────────────────────────────────────┐     │
│  │ ca.crt (Public) + ca.key (Private - PROTECTED) │     │
│  └────────────────────────────────────────────────┘     │
│                       │                                   │
│                       │ Signs (using ca.key)             │
│                       ▼                                   │
│  ┌─────────────────────────────────────────────────┐    │
│  │ Signed Certificates:                            │    │
│  │ • apiserver.crt                                 │    │
│  │ • apiserver-kubelet-client.crt                  │    │
│  │ • controller-manager.crt                        │    │
│  │ • scheduler.crt                                 │    │
│  │ • admin client cert (embedded in admin.conf)    │    │
│  │ • kubelet-client-YYYY.pem (via CSR approval)    │    │
│  └─────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│  ETCD CA (Separate Certificate Authority)                │
│  Location: /etc/kubernetes/pki/etcd/                     │
│  ┌────────────────────────────────────────────────┐     │
│  │ ca.crt (Public) + ca.key (Private - PROTECTED) │     │
│  └────────────────────────────────────────────────┘     │
│                       │                                   │
│                       │ Signs (using ca.key)             │
│                       ▼                                   │
│  ┌─────────────────────────────────────────────────┐    │
│  │ Signed Certificates:                            │    │
│  │ • etcd/server.crt (for client connections)      │    │
│  │ • etcd/peer.crt (for etcd-to-etcd)             │    │
│  │ • apiserver-etcd-client.crt                     │    │
│  └─────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│  KUBELET CA (Per-Node or Cluster CA)                     │
│  Location: /var/lib/kubelet/pki/                         │
│  ┌────────────────────────────────────────────────┐     │
│  │ Option 1: Uses cluster CA                       │     │
│  │ Option 2: Self-signed kubelet CA per node      │     │
│  └────────────────────────────────────────────────┘     │
│                       │                                   │
│                       │ Signs (using appropriate CA)     │
│                       ▼                                   │
│  ┌─────────────────────────────────────────────────┐    │
│  │ Signed Certificates:                            │    │
│  │ • kubelet.crt (server cert for port 10250)      │    │
│  │ • kubelet.key (private key)                     │    │
│  └─────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────┘
```

---

## 🔄 Flow 1: API Server ↔ ETCD (Full mTLS)

```
┌─────────────────┐                              ┌──────────────┐
│  API SERVER     │        Port 2379             │     ETCD     │
│  (Client)       │◄────────────────────────────►│   (Server)   │
└─────────────────┘                              └──────────────┘

Certificates Used:
─────────────────────────────────────────────────────────────────
API Server:                          ETCD:
• apiserver-etcd-client.crt         • etcd/server.crt
• apiserver-etcd-client.key         • etcd/server.key
• etcd/ca.crt (to verify)           • etcd/ca.crt (to verify)


HANDSHAKE FLOW:
═══════════════════════════════════════════════════════════════

Step 1: TCP Connection
──────────────────────
API Server ───► ETCD (port 2379)

Step 2: TLS ClientHello
──────────────────────
API Server ───► ETCD
              │ 
              ├─ Supported TLS versions
              ├─ Random nonce
              ├─ Cipher suites
              └─ SNI: hostname

Step 3: ServerHello
──────────────────────
API Server ◄─── ETCD
              │
              ├─ Chosen cipher
              └─ Random nonce

Step 4: ETCD Server Certificate
──────────────────────────────────
API Server ◄─── ETCD sends: etcd/server.crt
              │
              └─ Signed by: etcd/ca.crt

API Server Verifies:
  ✓ Is cert signed by etcd/ca.crt?
  ✓ Is cert valid (not expired)?
  ✓ Do SANs match endpoint?

Step 5: ETCD Proves Private Key
──────────────────────────────────
ETCD uses etcd/server.key internally to sign handshake
(Private key NEVER transmitted)

Step 6: Certificate Request
──────────────────────────────────
API Server ◄─── ETCD requests client certificate

Step 7: API Server Sends Client Certificate
──────────────────────────────────────────────
API Server ───► ETCD sends: apiserver-etcd-client.crt
              │
              └─ Signed by: etcd/ca.crt

ETCD Verifies:
  ✓ Is cert signed by etcd/ca.crt?
  ✓ Is cert valid?
  ✓ Is CN/O authorized?

Step 8: API Server Proves Private Key
──────────────────────────────────────
API Server uses apiserver-etcd-client.key to sign handshake
(Private key NEVER transmitted)

Step 9: Session Keys
──────────────────────
Both derive symmetric session key
  ✓ mTLS Complete
  ✓ Encrypted communication begins

═══════════════════════════════════════════════════════════════
```

---

## 🔄 Flow 2: API Server ↔ Kubelet (Full mTLS)

```
┌─────────────────┐                              ┌──────────────┐
│  API SERVER     │        Port 10250            │   KUBELET    │
│  (Client)       │◄────────────────────────────►│   (Server)   │
└─────────────────┘                              └──────────────┘

Used for: logs, exec, port-forward, metrics, probes

Certificates Used:
─────────────────────────────────────────────────────────────────
API Server:                          Kubelet:
• apiserver-kubelet-client.crt      • kubelet.crt
• apiserver-kubelet-client.key      • kubelet.key
• ca.crt (cluster CA, to verify)    • ca.crt (to verify)


HANDSHAKE FLOW:
═══════════════════════════════════════════════════════════════

Step 1: TCP Connection
──────────────────────
API Server ───► Kubelet (port 10250)

Step 2: TLS ClientHello
──────────────────────
API Server ───► Kubelet
              │ 
              ├─ Supported TLS versions
              ├─ Random nonce
              └─ Cipher suites

Step 3: ServerHello + Certificate
──────────────────────────────────
API Server ◄─── Kubelet sends: kubelet.crt
              │
              └─ Signed by: cluster ca.crt

API Server Verifies:
  ✓ Is cert signed by /etc/kubernetes/pki/ca.crt?
  ✓ Is cert valid?
  ✓ Do SANs match kubelet IP/hostname?

Step 4: Kubelet Proves Private Key
──────────────────────────────────
Kubelet uses kubelet.key to sign handshake

Step 5: Certificate Request
──────────────────────────────────
API Server ◄─── Kubelet requests client certificate

Step 6: API Server Sends Client Certificate
──────────────────────────────────────────────
API Server ───► Kubelet sends: apiserver-kubelet-client.crt
              │
              └─ Signed by: cluster ca.crt

Kubelet Verifies:
  ✓ Is cert signed by cluster ca.crt?
  ✓ Is cert valid?
  ✓ Check CN: system:masters group
  ✓ Check O: system:masters organization

Step 7: API Server Proves Private Key
──────────────────────────────────────
API Server uses apiserver-kubelet-client.key to sign handshake

Step 8: Session Keys
──────────────────────
Both derive symmetric session key
  ✓ mTLS Complete
  ✓ API can now call kubelet APIs

═══════════════════════════════════════════════════════════════
```

---

## 🔄 Flow 3: Kubelet ↔ API Server (Client Authentication)

```
┌──────────────┐                              ┌─────────────────┐
│   KUBELET    │        Port 6443             │   API SERVER    │
│  (Client)    │◄────────────────────────────►│    (Server)     │
└──────────────┘                              └─────────────────┘

Used for: Watch pods, update status, fetch secrets/configmaps

Certificates Used:
─────────────────────────────────────────────────────────────────
Kubelet:                             API Server:
• kubelet-client-current.pem        • apiserver.crt
• kubelet-client-current.key        • apiserver.key
• ca.crt (to verify API server)     • ca.crt (to verify clients)


HANDSHAKE FLOW:
═══════════════════════════════════════════════════════════════

Step 1: TCP Connection
──────────────────────
Kubelet ───► API Server (port 6443)

Step 2: TLS ClientHello
──────────────────────
Kubelet ───► API Server
           │ 
           ├─ Supported TLS versions
           ├─ Random nonce
           └─ Cipher suites

Step 3: ServerHello + Certificate
──────────────────────────────────
Kubelet ◄─── API Server sends: apiserver.crt
           │
           └─ Signed by: cluster ca.crt

Kubelet Verifies:
  ✓ Is cert signed by /var/lib/kubelet/pki/ca.crt?
  ✓ Is cert valid?
  ✓ Do SANs include kubernetes, kubernetes.default, etc?

Step 4: API Server Proves Private Key
──────────────────────────────────────
API Server uses apiserver.key to sign handshake

Step 5: Certificate Request
──────────────────────────────────
Kubelet ◄─── API Server requests client certificate

Step 6: Kubelet Sends Client Certificate
──────────────────────────────────────────
Kubelet ───► API Server sends: kubelet-client-current.pem
           │
           └─ Signed by: cluster ca.crt (via CSR)

API Server Verifies:
  ✓ Is cert signed by cluster ca.crt?
  ✓ Is cert valid?
  ✓ Check CN: system:node:<node-name>
  ✓ Check O: system:nodes

Step 7: Kubelet Proves Private Key
──────────────────────────────────
Kubelet uses kubelet-client-current.key to sign handshake

Step 8: RBAC Authorization
──────────────────────────
API Server checks:
  ✓ Node authorization mode
  ✓ RBAC rules for system:nodes group
  ✓ Restricts access to node's own resources

Step 9: Session Keys
──────────────────────
Both derive symmetric session key
  ✓ mTLS Complete
  ✓ Kubelet can now call API

═══════════════════════════════════════════════════════════════

CERTIFICATE ROTATION (Auto-Renewal):
═══════════════════════════════════════════════════════════════

Kubelet ───► API Server: POST /apis/certificates.k8s.io/v1/
           │              certificatesigningrequests
           │
           └─ Creates CSR with new public key

Controller Manager ───► Approves CSR (if valid)
                    └─ Signs with cluster CA

Kubelet ◄─── Fetches signed certificate

Kubelet ───► Stores as: kubelet-client-YYYY-MM-DD.pem
           └─ Symlinks to: kubelet-client-current.pem

Rotation triggers ~30 days before expiry
═══════════════════════════════════════════════════════════════
```

---

## 🔄 Flow 4: kubectl (Admin) ↔ API Server (mTLS)

```
┌──────────────┐                              ┌─────────────────┐
│   kubectl    │        Port 6443             │   API SERVER    │
│   (Admin)    │◄────────────────────────────►│    (Server)     │
└──────────────┘                              └─────────────────┘

Certificates Used (from kubeconfig):
─────────────────────────────────────────────────────────────────
kubectl:                             API Server:
• client-certificate-data           • apiserver.crt
• client-key-data                   • apiserver.key
• certificate-authority-data        • ca.crt (to verify clients)

Location: ~/.kube/config OR /etc/kubernetes/admin.conf


HANDSHAKE FLOW:
═══════════════════════════════════════════════════════════════

Step 1: TCP Connection
──────────────────────
kubectl ───► API Server (port 6443)

Step 2: TLS ClientHello
──────────────────────
kubectl ───► API Server
          │ 
          ├─ Supported TLS versions
          ├─ Random nonce
          └─ Cipher suites

Step 3: ServerHello + Certificate
──────────────────────────────────
kubectl ◄─── API Server sends: apiserver.crt
          │
          └─ Signed by: cluster ca.crt

kubectl Verifies:
  ✓ Is cert signed by certificate-authority-data from kubeconfig?
  ✓ Is cert valid?
  ✓ Does server match kubeconfig URL?

Step 4: API Server Proves Private Key
──────────────────────────────────────
API Server uses apiserver.key to sign handshake

Step 5: Certificate Request
──────────────────────────────────
kubectl ◄─── API Server requests client certificate

Step 6: kubectl Sends Client Certificate
──────────────────────────────────────────
kubectl ───► API Server sends: client-certificate-data
          │                     (admin client cert)
          │
          └─ Signed by: cluster ca.crt

API Server Verifies:
  ✓ Is cert signed by cluster ca.crt?
  ✓ Is cert valid?
  ✓ Extract CN: kubernetes-admin
  ✓ Extract O: system:masters

Step 7: kubectl Proves Private Key
──────────────────────────────────
kubectl uses client-key-data to sign handshake

Step 8: RBAC Authorization
──────────────────────────
API Server checks:
  ✓ Group "system:masters" = cluster-admin
  ✓ Full cluster access granted

Step 9: Session Keys
──────────────────────
Both derive symmetric session key
  ✓ mTLS Complete
  ✓ kubectl can execute commands

═══════════════════════════════════════════════════════════════

KUBECONFIG STRUCTURE:
═══════════════════════════════════════════════════════════════
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: <base64 ca.crt>  ← Cluster CA
    server: https://10.0.0.1:6443
  name: kubernetes
users:
- name: kubernetes-admin
  user:
    client-certificate-data: <base64 admin.crt>  ← Client cert
    client-key-data: <base64 admin.key>          ← Private key
contexts:
- context:
    cluster: kubernetes
    user: kubernetes-admin
  name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes
═══════════════════════════════════════════════════════════════
```

---

## 🔄 Flow 5: Controller Manager / Scheduler ↔ API Server

```
┌──────────────────┐                         ┌─────────────────┐
│ CONTROLLER-MGR / │     Port 6443           │   API SERVER    │
│   SCHEDULER      │◄───────────────────────►│    (Server)     │
└──────────────────┘                         └─────────────────┘

Certificates Used:
─────────────────────────────────────────────────────────────────
Controller/Scheduler:                API Server:
• controller-manager.crt or         • apiserver.crt
  scheduler.crt                     • apiserver.key
• controller-manager.key or         • ca.crt (to verify)
  scheduler.key
• ca.crt (to verify API)

Location: /etc/kubernetes/pki/


FLOW (Same as kubectl, different certs):
═══════════════════════════════════════════════════════════════

1. TCP Connection to API Server
2. API sends apiserver.crt → verified by ca.crt
3. API proves private key with apiserver.key
4. Controller/Scheduler sends their client cert
5. API verifies using cluster ca.crt
6. Controller/Scheduler proves private key
7. RBAC check (system:kube-controller-manager group)
8. mTLS established

These run as static pods on control plane, but still use mTLS!
═══════════════════════════════════════════════════════════════
```

---

## 🔄 Flow 6: Pod ↔ API Server (TLS + Bearer Token)

```
┌──────────────┐                              ┌─────────────────┐
│     POD      │        Port 6443             │   API SERVER    │
│ (Application)│◄────────────────────────────►│    (Server)     │
└──────────────┘                              └─────────────────┘

NOT mTLS - Uses JWT Bearer Token Authentication

Mounted Files in Pod:
─────────────────────────────────────────────────────────────────
Location: /var/run/secrets/kubernetes.io/serviceaccount/

• ca.crt        ← Cluster CA to verify API server
• token         ← JWT signed by API server
• namespace     ← Pod's namespace


HANDSHAKE FLOW:
═══════════════════════════════════════════════════════════════

Step 1: TCP Connection
──────────────────────
Pod ───► API Server (port 6443)

Step 2: TLS ClientHello
──────────────────────
Pod ───► API Server
       │ 
       ├─ Supported TLS versions
       └─ Cipher suites

Step 3: ServerHello + Certificate
──────────────────────────────────
Pod ◄─── API Server sends: apiserver.crt
       │
       └─ Signed by: cluster ca.crt

Pod Verifies:
  ✓ Is cert signed by /var/run/secrets/.../ca.crt?
  ✓ Is cert valid?

Step 4: API Server Proves Private Key
──────────────────────────────────────
API Server uses apiserver.key to sign handshake

Step 5: NO CLIENT CERTIFICATE
──────────────────────────────────
Pod does NOT send a client certificate
(This is TLS, not mTLS)

Step 6: Session Keys
──────────────────────
Session key established
  ✓ TLS Complete (Server-side only)

Step 7: HTTP Request with Bearer Token
──────────────────────────────────────
Pod ───► API Server
       │
       │ GET /api/v1/namespaces/default/pods
       │ Authorization: Bearer eyJhbGciOiJS...
       │
       └─ JWT token from /var/run/secrets/.../token

Step 8: Token Verification
──────────────────────────
API Server:
  ✓ Verifies JWT signature using /etc/kubernetes/pki/sa.pub
  ✓ Checks token expiry
  ✓ Extracts ServiceAccount: system:serviceaccount:default:default
  ✓ Checks RBAC permissions for ServiceAccount

Step 9: Response
──────────────────────────
API Server ───► Pod: 200 OK (if authorized)

═══════════════════════════════════════════════════════════════

JWT TOKEN STRUCTURE:
═══════════════════════════════════════════════════════════════
Header:
{
  "alg": "RS256",
  "kid": "..."
}

Payload:
{
  "iss": "kubernetes/serviceaccount",
  "kubernetes.io/serviceaccount/namespace": "default",
  "kubernetes.io/serviceaccount/service-account.name": "default",
  "sub": "system:serviceaccount:default:default",
  "exp": 1234567890
}

Signature: Signed with /etc/kubernetes/pki/sa.key
Verified with: /etc/kubernetes/pki/sa.pub
═══════════════════════════════════════════════════════════════
```

---

## 📊 Complete Communication Matrix

```
╔═══════════════════════════════════════════════════════════════════════╗
║  Connection            │ Type   │ Client Cert          │ Server Cert  ║
╠═══════════════════════════════════════════════════════════════════════╣
║  apiserver → etcd      │ mTLS   │ apiserver-etcd-      │ etcd/server  ║
║                        │        │ client.crt           │ .crt         ║
║                        │        │ (etcd CA)            │ (etcd CA)    ║
╠═══════════════════════════════════════════════════════════════════════╣
║  apiserver → kubelet   │ mTLS   │ apiserver-kubelet-   │ kubelet.crt  ║
║                        │        │ client.crt           │              ║
║                        │        │ (cluster CA)         │ (cluster CA) ║
╠═══════════════════════════════════════════════════════════════════════╣
║  kubelet → apiserver   │ mTLS   │ kubelet-client-      │ apiserver    ║
║                        │        │ current.pem          │ .crt         ║
║                        │        │ (cluster CA)         │ (cluster CA) ║
╠═══════════════════════════════════════════════════════════════════════╣
║  kubectl → apiserver   │ mTLS   │ admin client cert    │ apiserver    ║
║                        │        │ (from admin.conf)    │ .crt         ║
║                        │        │ (cluster CA)         │ (cluster CA) ║
╠═══════════════════════════════════════════════════════════════════════╣
║  controller-mgr →      │ mTLS   │ controller-manager   │ apiserver    ║
║  apiserver             │        │ .crt                 │ .crt         ║
║                        │        │ (cluster CA)         │ (cluster CA) ║
╠═══════════════════════════════════════════════════════════════════════╣
║  scheduler →           │ mTLS   │ scheduler.crt        │ apiserver    ║
║  apiserver             │        │                      │ .crt         ║
║                        │        │ (cluster CA)         │ (cluster CA) ║
╠═══════════════════════════════════════════════════════════════════════╣
║  pod → apiserver       │ TLS    │ NONE                 │ apiserver    ║
║                        │ +JWT   │ (Bearer Token Auth)  │ .crt         ║
║                        │        │                      │ (cluster CA) ║
╚═══════════════════════════════════════════════════════════════════════╝
```

---

## 🔍 Certificate Verification Process

```
When Component A connects to Component B:
═══════════════════════════════════════════════════════════════

┌──────────────────────────────────────────────────────────────┐
│ Step 1: B sends its certificate (e.g., server.crt)          │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│ Step 2: A loads its trusted CA certificate (ca.crt)         │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│ Step 3: A verifies server.crt signature using ca.crt        │
│                                                              │
│   Verification checks:                                       │
│   ✓ Certificate signature matches CA's public key           │
│   ✓ Certificate is not expired                              │
│   ✓ Certificate is not revoked (if CRL/OCSP used)          │
│   ✓ Certificate chain is valid                              │
│   ✓ SAN/CN matches endpoint hostname/IP                     │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│ Step 4: B proves it owns the private key                    │
│         (signs handshake data, A verifies with cert)        │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│ Step 5: If mTLS, repeat for client certificate              │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│ Step 6: Derive session keys, encrypted channel established  │
└──────────────────────────────────────────────────────────────┘
```

---

## 📁 Complete File Location Reference

```
/etc/kubernetes/pki/
├── ca.crt                              ← Cluster CA (public)
├── ca.key                              ← Cluster CA (private) **PROTECTED**
├── apiserver.crt                       ← API server certificate
├── apiserver.key                       ← API server private key
├── apiserver-kubelet-client.crt        ← API→Kubelet client cert
├── apiserver-kubelet-client.key        ← API→Kubelet client key
├── apiserver-etcd-client.crt           ← API→ETCD client cert
├── apiserver-etcd-client.key           ← API→ETCD client key
├── front-proxy-ca.crt                  ← Front proxy CA
├── front-proxy-client.crt              ← Front proxy client
├── sa.key                              ← ServiceAccount signing key
├── sa.pub                              ← ServiceAccount public key
├── etcd/
│   ├── ca.crt                          ← ETCD CA (public)
│   ├── ca.key                          ← ETCD CA (private) **PROTECTED**
│   ├── server.crt                      ← ETCD server cert
│   ├── server.key                      ← ETCD server key
│   ├── peer.crt                        ← ETCD peer cert
│   └── peer.key                        ← ETCD peer key
└── [other certs for scheduler, controller-manager]

/var/lib/kubelet/pki/
├── kubelet.crt                         ← Kubelet server cert (port 10250)
├── kubelet.key                         ← Kubelet server key
├── kubelet-client-current.pem          ← Kubelet client cert (symlink)
└── kubelet-client-2024-11-23.pem       ← Actual client cert

/etc/kubernetes/
├── admin.conf                          ← Admin kubeconfig with embedded cert
├── controller-manager.conf             ← Controller-manager kubeconfig
├── scheduler.conf                      ← Scheduler kubeconfig
└── kubelet.conf                        ← Kubelet kubeconfig

/var/run/secrets/kubernetes.io/serviceaccount/  (in pods)
├── ca.crt                              ← Cluster CA for verification
├── token                               ← JWT bearer token
└── namespace                           ← Pod's namespace
```

---

## 🎯 Key Takeaways

### 1. **Separate Certificate Authorities**
- **Cluster CA**: Signs most certificates (apiserver, kubelet, users)
- **ETCD CA**: Separate authority for etcd isolation
- **Kubelet CA**: Can be cluster CA or per-node self-signed

### 2. **mTLS vs TLS**
- **mTLS**: Both client and server present certificates
  - apiserver ↔ etcd
  - apiserver ↔ kubelet
  - kubelet ↔ apiserver
  - kubectl ↔ apiserver
  
- **TLS + JWT**: Only server presents certificate
  - pod ↔ apiserver (uses bearer token)

### 3. **Admin Access**
- Old method: admin.crt + admin.key files
- **Current method**: Credentials embedded in /etc/kubernetes/admin.conf
- Contains base64-encoded certificate and key

### 4. **Kubelet Certificates**
- **Server cert** (kubelet.crt): For incoming connections on port 10250
- **Client cert** (kubelet-client-*.pem): For outgoing API server calls
- Client certs auto-rotate via CSR API

### 5. **Private Keys Never Travel**
- Private keys prove ownership during handshake
- They sign data, but are never transmitted
- Each component validates signatures using public certificates
