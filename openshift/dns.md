## Kubernetes DNS for Service Discovery

**Overview**:
Kubernetes employs an internal DNS system to resolve service names to IP addresses, enabling pod-to-service and pod-to-pod communication within the cluster. This is managed by the **DNS operator** using the `operator.openshift.io` API group.

**Components and Operation**:
1. **DNS Operator and CoreDNS**:
   - The DNS operator deploys **CoreDNS** as the cluster’s DNS server.
   - CoreDNS runs as a service with a cluster IP (e.g., `172.30.0.10`), defined by a `Service` resource.
   - The operator configures the kubelet to inject this IP into each pod’s `/etc/resolv.conf` for name resolution.

2. **Service DNS Records**:
   - Each service is assigned a **Fully Qualified Domain Name (FQDN)**:
     ```
     <service-name>.<namespace>.svc.<cluster-domain>
     ```
     Example: For a service `myapp` in namespace `deploy-services` with cluster domain `cluster.local`, the FQDN is:
     ```
     myapp.deploy-services.svc.cluster.local
     ```
   - For **headless services** (no cluster IP), CoreDNS creates `A` records resolving to the IP addresses of the backing pods.

3. **Pod DNS Configuration**:
   - Pods receive a `/etc/resolv.conf` file, typically containing:
     ```bash
     search <namespace>.svc.cluster.local svc.cluster.local cluster.local
     nameserver <coredns-service-ip>
     options ndots:5
     ```
     - **nameserver**: Specifies CoreDNS’s service IP (e.g., `172.30.0.10`).
     - **search**: Defines domains appended to unqualified names. For example, a pod querying `myapp` resolves to `myapp.<namespace>.svc.cluster.local`.
     - **ndots:5**: Names with fewer than 5 dots are tried with search domains before external queries.

4. **Resolution Logic**:
   - Pods can resolve services using:
     - Short name: `myapp` (same namespace).
     - Partial name: `myapp.<namespace>` (cross-namespace).
     - Full FQDN: `myapp.<namespace>.svc.<cluster-domain>`.
   - CoreDNS handles queries internally, ensuring cluster-scoped resolution.

**Purpose**:
This system abstracts service IPs, allowing dynamic IP reassignment without breaking communication, critical for Kubernetes’ self-healing architecture.

---

### Kubernetes Networking and CNI Plugins

**Overview**:
Kubernetes networking relies on the **Container Network Interface (CNI)** specification to configure pod networking, ensuring pod-to-pod, pod-to-service, and external communication. RHOCP integrates CNI plugins to manage the cluster network.

**Components and Operation**:
1. **CNI Plugins**:
   - CNI defines a standard for plugins to configure container network interfaces. RHOCP supports:
     - **OVN-Kubernetes**: Default since RHOCP 4.10, using Open Virtual Network (OVN).
     - **OpenShift SDN**: Legacy plugin from RHOCP 3.x, limited compatibility with RHOCP 4.x features.
     - **Kuryr**: Tailored for OpenStack integration.
     - **Vendor Plugins**: Certified third-party plugins (e.g., Calico, Weave).

2. **OVN-Kubernetes**:
   - Implements a virtualized overlay network using **Open vSwitch (OVS)** on each node.
   - OVN manages logical switches, routers, and ACLs to enforce network policies.
   - Assigns each pod a unique IP from the **Cluster Network CIDR** (e.g., `10.8.0.0/14`).
   - Pods share a Linux network namespace per node, with isolated IP stacks and routing tables.

3. **Network Architecture**:
   - Pods are allocated IPs with a **host prefix** (e.g., `/23`, yielding 512 IPs per node).
   - Services receive IPs from the **Service Network CIDR** (e.g., `172.30.0.0/16`).
   - OVN-Kubernetes ensures pod IPs are routable within the cluster, supporting direct pod-to-pod communication.

---

### Cluster Network Operator (CNO)

**Overview**:
The **Cluster Network Operator (CNO)**, part of RHOCP’s operator framework, manages cluster networking configuration and monitors its health.

**Components and Operation**:
1. **Responsibilities**:
   - Deploys and configures the selected CNI plugin (e.g., OVN-Kubernetes).
   - Defines network parameters:
     - **Cluster Network CIDR**: IP range for pod IPs (e.g., `10.8.0.0/14`).
     - **Service Network CIDR**: IP range for service IPs (e.g., `172.30.0.0/16`).
     - **Host Prefix**: Subnet size per node (e.g., `/23`).
   - Monitors network components for availability.

2. **Inspection Commands**:
   - Check CNO status:
     ```bash
     oc get -n openshift-network-operator deployment/network-operator
     ```
     Example output:
     ```
     NAME              READY   UP-TO-DATE  AVAILABLE   AGE
     network-operator  1/1     1           1           41d
     ```
   - View network configuration:
     ```bash
     oc describe network.config/cluster
     ```
     Example output:
     ```
     Spec:
       Cluster Network:
         Cidr: 10.8.0.0/14
         Host Prefix: 23
       Network Type: OVNKubernetes
       Service Network:
         172.30.0.0/16
     ```

**Purpose**:
The CNO ensures consistent network configuration across the cluster, abstracting low-level networking details from administrators.

---

### Summary

- **DNS**: CoreDNS resolves service names to IPs using FQDNs (`<service>.<namespace>.svc.<cluster-domain>`). Pods use `/etc/resolv.conf` to query CoreDNS, supporting short and full names for intra- and cross-namespace communication.
- **Networking**: OVN-Kubernetes (default in RHOCP 4.14) provides a virtualized network with OVS, assigning unique pod IPs and managing traffic with logical overlays.
- **CNO**: Configures the CNI plugin and IP ranges, ensuring network stability and scalability.

