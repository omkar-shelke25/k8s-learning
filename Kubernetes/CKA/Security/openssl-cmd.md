# Notes on Using OpenSSL and Kubernetes CSR API for SSL/TLS Certificates

## 1. Using OpenSSL for Certificate Preparation

### 1.1 Checking OpenSSL Version
- **Purpose**: Confirm the OpenSSL version to ensure compatibility with required cryptographic algorithms and protocols (e.g., TLS 1.1/1.2 support since OpenSSL 1.0.1).
- **Command**:
  ```bash
  openssl version -a
  ```
- **Output Includes**:
  - Version and release date (e.g., `OpenSSL 1.0.2g 1 Mar 2016`).
  - Build options (e.g., `bn(64,64) rc4(16x,int)`).
  - Certificate/private key directory (`OPENSSLDIR: "/usr/lib/ssl"`).
- **Importance**: Ensures compatibility with Kubernetes and CA requirements.

### 1.2 Generating a Private Key
- **Algorithm**: RSA (recommended for compatibility) or ECDSA (check compatibility).
- **Key Size**: Minimum 2048 bits (RSA) or 256 bits (ECDSA). Avoid default 512-bit keys (insecure).
- **Passphrase**: Optional; avoid for automated Kubernetes deployments.
- **Command** (RSA, 2048 bits, no passphrase):
  ```bash
  openssl genrsa -out yourdomain.key 2048
  ```
- **Output**: Private key in PEM format (`yourdomain.key`).
- **View Key**:
  - Raw: `cat yourdomain.key`
  - Decoded: `openssl rsa -text -in yourdomain.key -noout`

### 1.3 Extracting Public Key
- **Purpose**: Extract public key for verification or use.
- **Command**:
  ```bash
  openssl rsa -in yourdomain.key -pubout -out yourdomain_public.key
  ```
- **Output**: Public key in PEM format (`yourdomain_public.key`).

### 1.4 Creating a Certificate Signing Request (CSR)
- **Purpose**: Generate a CSR for submission to a CA (e.g., Kubernetes CA or external CA like DigiCert).
- **Interactive Command**:
  ```bash
  openssl req -new -key yourdomain.key -out yourdomain.csr
  ```
  - **Prompts**:
    - Country Name (C): 2-letter code (e.g., `US`).
    - State/Province (ST): Full name (e.g., `Utah`).
    - Locality (L): City (e.g., `Lehi`).
    - Organization (O): Company name (e.g., `Your Company, Inc.`).
    - Organizational Unit (OU): Department (e.g., `IT`, optional).
    - Common Name (CN): Fully qualified domain name (e.g., `yourdomain.com`).
    - Email Address: Optional.
    - Challenge Password: Optional.
    - Optional Company Name: Optional.
  - **Tip**: Enter `.` to skip a field without using defaults.
- **Non-Interactive Command**:
  ```bash
  openssl req -new -key yourdomain.key -out yourdomain.csr \
  -subj "/C=US/ST=Utah/L=Lehi/O=Your Company, Inc./OU=IT/CN=yourdomain.com"
  ```
- **Combined Key and CSR**:
  ```bash
  openssl req -new -newkey rsa:2048 -nodes -keyout yourdomain.key \
  -out yourdomain.csr \
  -subj "/C=US/ST=Utah/L=Lehi/O=Your Company, Inc./OU=IT/CN=yourdomain.com"
  ```
- **Note**: Adding Subject Alternative Names (SANs) in OpenSSL is complex; use CA’s order form for SANs.

### 1.5 Verifying CSR
- **Purpose**: Confirm CSR content and integrity.
- **Command**:
  ```bash
  openssl req -text -in yourdomain.csr -noout -verify
  ```
- **Output**: `verify OK` and subject/public key details.
- **Action**: Regenerate CSR if errors are found (CSRs cannot be edited).

### 1.6 Submitting CSR to CA
- **Command**: `cat yourdomain.csr`
- **Action**: Copy entire output (including `-----BEGIN/END CERTIFICATE REQUEST-----`) for submission.

### 1.7 Verifying Certificate
- **Purpose**: Ensure received certificate (`yourdomain.crt`) is correct.
- **Command**:
  ```bash
  openssl x509 -text -in yourdomain.crt -noout
  ```

### 1.8 Verifying Key-Certificate Match
- **Purpose**: Confirm private key, CSR, and certificate share the same public key.
- **Commands**:
  ```bash
  openssl pkey -pubout -in yourdomain.key | openssl sha256
  openssl req -pubkey -in yourdomain.csr -noout | openssl sha256
  openssl x509 -pubkey -in yourdomain.crt -noout | openssl sha256
  ```
- **Output**: Matching hashes confirm consistency.
- **Mismatch Solutions**:
  - Transfer private key to target machine.
  - Install certificate on machine with private key.
  - Generate new key and CSR.

### 1.9 Converting Formats
- **PEM to PKCS#12 (.pfx)**:
  ```bash
  openssl pkcs12 -export -name "yourdomain-digicert-(expiration date)" \
  -out yourdomain.pfx -inkey yourdomain.key -in yourdomain.crt
  ```
- **PKCS#12 to PEM**:
  - Private key: `openssl pkcs12 -in yourdomain.pfx -nocerts -out yourdomain.key -nodes`
  - Certificate: `openssl pkcs12 -in yourdomain.pfx -nokeys -clcerts -out yourdomain.crt`
- **PEM to DER**:
  - Certificate: `openssl x509 -inform PEM -in yourdomain.crt -outform DER -out yourdomain.der`
  - Private key: `openssl rsa -inform PEM -in yourdomain.key -outform DER -out yourdomain_key.der`

## 2. Kubernetes Certificate Signing Request (CSR) API

### 2.1 Overview
- The Kubernetes CSR API (`certificates.k8s.io/v1`) enables requesting certificates from a CA (Kubernetes' built-in CA or external CA) for securing cluster components or workloads.
- **Use Cases**:
  - **Client Authentication**: Issue certificates for users or services to authenticate with the Kubernetes API.
  - **Server Certificates**: Secure kubelet, ingress, or custom application endpoints.
  - **Service Mesh**: Provide certificates for secure service-to-service communication (e.g., Istio).
  - **External Services**: Secure external-facing services with CA-issued certificates.

### 2.2 Step-by-Step Process

#### Step 1: Generate Private Key and CSR
- Use OpenSSL to create a private key and CSR:
  ```bash
  openssl genrsa -out yourdomain.key 2048
  openssl req -new -key yourdomain.key -out yourdomain.csr \
  -subj "/C=US/ST=Utah/L=Lehi/O=Your Company, Inc./OU=IT/CN=yourdomain.com"
  ```
- Encode CSR in base64 for Kubernetes:
  ```bash
  cat yourdomain.csr | base64 | tr -d '\n'
  ```

#### Step 2: Create a Kubernetes CSR Object
- Create a `csr.yaml` file with the CSR details:
  ```yaml
  apiVersion: certificates.k8s.io/v1
  kind: CertificateSigningRequest
  metadata:
    name: yourdomain-csr
  spec:
    request: <base64-encoded-CSR>
    signerName: kubernetes.io/kube-apiserver-client
    expirationSeconds: 86400  # 1 day
    usages:
    - client auth
  ```
- **Parameters**:
  - `metadata.name`: Unique name for the CSR object (e.g., `yourdomain-csr`).
  - `spec.request`: Base64-encoded CSR from OpenSSL.
  - `spec.signerName`: Specifies the CA or certificate purpose:
    - `kubernetes.io/kube-apiserver-client`: For client authentication to the API server.
    - `kubernetes.io/kubelet-serving`: For kubelet server certificates.
    - `kubernetes.io/legacy-unknown`: For external CAs or custom signers.
  - `spec.expirationSeconds`: Certificate validity duration (e.g., 86400 seconds = 1 day).
  - `spec.usages`: Certificate usage types:
    - `client auth`: For client authentication.
    - `server auth`: For server authentication (e.g., Ingress, kubelet).
    - `digital signature`, `key encipherment`, etc., for specific cryptographic operations.
- Apply the CSR:
  ```bash
  kubectl apply -f csr.yaml
  ```

#### Step 3: Approve the CSR
- Check CSR status:
  ```bash
  kubectl get csr yourdomain-csr
  ```
- Approve the CSR (requires cluster-admin permissions):
  ```bash
  kubectl certificate approve yourdomain-csr
  ```
- **Note**: Some clusters use automatic approval via controllers (e.g., `kube-controller-manager`).

#### Step 4: Retrieve the Signed Certificate
- Extract the signed certificate:
  ```bash
  kubectl get csr yourdomain-csr -o jsonpath='{.status.certificate}' | base64 --decode > yourdomain.crt
  ```
- **Output**: Signed certificate in PEM format (`yourdomain.crt`).

#### Step 5: Verify Certificate
- Check certificate details:
  ```bash
  openssl x509 -text -in yourdomain.crt -noout
  ```
- Verify key-certificate match:
  ```bash
  openssl pkey -pubout -in yourdomain.key | openssl sha256
  openssl x509 -pubkey -in yourdomain.crt -noout | openssl sha256
  ```

#### Step 6: Create a Kubernetes Secret
- Store the private key and certificate in a TLS secret:
  ```bash
  kubectl create secret tls yourdomain-tls \
  --key yourdomain.key \
  --cert yourdomain.crt \
  -n <namespace>
  ```

### 2.3 Using Key and Certificate in Kubernetes

#### Method 1: Ingress (HTTPS for External Services)
- Use the TLS secret in an Ingress resource for HTTPS:
  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: yourdomain-ingress
    namespace: <namespace>
  spec:
    tls:
    - hosts:
      - yourdomain.com
      secretName: yourdomain-tls
    rules:
    - host: yourdomain.com
      http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: your-service
              port:
                number: 80
  ```
- Apply: `kubectl apply -f ingress.yaml`
- **Use Case**: Secure external-facing web applications.

#### Method 2: Kubernetes API Server
- Mount the TLS secret to secure API server communication:
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: kube-apiserver
    namespace: kube-system
  spec:
    containers:
    - name: kube-apiserver
      image: k8s.gcr.io/kube-apiserver:v1.25.0
      command:
      - kube-apiserver
      - --tls-cert-file=/etc/tls/yourdomain.crt
      - --tls-private-key-file=/etc/tls/yourdomain.key
      volumeMounts:
      - name: tls-cert
        mountPath: /etc/tls
        readOnly: true
    volumes:
    - name: tls-cert
      secret:
        secretName: yourdomain-tls
  ```
- **Use Case**: Secure API server communication.

#### Method 3: Application Pods
- Mount the TLS secret into a pod for application use:
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: your-app
    namespace: <namespace>
  spec:
    containers:
    - name: your-app
      image: your-image
      volumeMounts:
      - name: tls-cert
        mountPath: /etc/tls
        readOnly: true
    volumes:
    - name: tls-cert
      secret:
        secretName: yourdomain-tls
  ```
- **Use Case**: Applications requiring TLS for internal or external communication.

#### Method 4: Client Authentication (User or Service Account)
- Use the certificate for Kubernetes API client authentication.
- Create a kubeconfig file:
  ```bash
  kubectl config set-credentials your-user \
  --client-certificate=yourdomain.crt \
  --client-key=yourdomain.key
  kubectl config set-context your-context \
  --cluster=your-cluster \
  --user=your-user
  ```
- **Use Case**: Authenticate users or services to the Kubernetes API.

#### Method 5: Service Mesh (e.g., Istio)
- Inject the TLS secret into Istio for service-to-service encryption:
  ```yaml
  apiVersion: networking.istio.io/v1alpha3
  kind: DestinationRule
  metadata:
    name: yourdomain-destination
    namespace: <namespace>
  spec:
    host: yourdomain.com
    trafficPolicy:
      tls:
        mode: MUTUAL
        clientCertificate: /etc/tls/tls.crt
        privateKey: /etc/tls/tls.key
  ```
- Mount the secret into Istio-enabled pods (similar to Method 3).
- **Use Case**: Secure microservices communication in a service mesh.

#### Method 6: External CA Integration
- If using an external CA (e.g., DigiCert):
  - Submit the CSR (`yourdomain.csr`) to the CA.
  - Receive the signed certificate (`yourdomain.crt`).
  - Create a Kubernetes secret: `kubectl create secret tls yourdomain-tls --key yourdomain.key --cert yourdomain.crt -n <namespace>`.
  - Use in Ingress, pods, or other resources as above.
- **Use Case**: Use trusted public CAs for externally accessible services.

### 2.4 Additional Notes
- **Automatic CSR Approval**: Configure `kube-controller-manager` with `--cluster-signing-cert-file` and `--cluster-signing-key-file` for automatic signing.
- **Security**: Store private keys securely; never expose them in logs or unsecured storage.
- **Rotation**: Periodically rotate certificates by generating new CSRs and updating secrets.
- **SANs**: For multiple domains, include SANs in the CSR or use CA’s interface.
