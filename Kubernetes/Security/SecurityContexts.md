# **SecurityContexts in Kubernetes: Deep Dive with Examples**

---

## **Introduction**

Hello and welcome to this lecture! In this session, we'll dive deep into **SecurityContexts** in Kubernetes. However, before we get there, it's essential to understand the basics of **security in Docker**, since Kubernetes uses Docker (or other container runtimes) as its foundation. If you're already familiar with Docker security concepts, feel free to skip ahead. But if you want a comprehensive understanding of container security from the ground up, this lecture is for you.

---

## **1. Security in Docker**

### **1.1. Basic Process Isolation in Docker**

Let's start with a host machine where Docker is installed. This host has multiple processes running, such as:

- **Operating System processes** (like `init`, `systemd`)
- The **Docker daemon** (`dockerd`)
- An **SSH server** (`sshd`)
- And other user-level applications.

Now, when you run an **Ubuntu Docker container** with a simple command like:

```bash
docker run -d ubuntu sleep 3600
```

This will start a process inside the container that simply sleeps for an hour.

#### **Key Point:**  
Unlike virtual machines, **containers are not fully isolated** from their host. Both the host and the container **share the same kernel**, but their **namespaces** provide isolation at the process, network, and filesystem levels.

---

### **1.2. Linux Namespaces and Process Isolation**

- **Namespaces** in Linux isolate resources for each container.
- The **host** has its own namespace, and **each container** has its **own separate namespace**.
  
#### **How It Works:**
- From the container's perspective, it only sees its processes within its namespace.
- When you list processes **inside** the container using:

  ```bash
  ps aux
  ```

  You will see the **`sleep` process** with a **Process ID (PID) of 1**.

- But if you check the processes on the **host** using:

  ```bash
  ps aux | grep sleep
  ```

  You’ll see the same `sleep` process, but with a **different PID**.

#### **Why Different PIDs?**
Because **PIDs are namespace-specific**. The container thinks the process is PID 1, but the host recognizes it as another process with a different PID.

---

### **1.3. User Contexts in Docker: Running as Root**

The **Docker host** has its own set of users:

- The **root user**
- Various **non-root users**

By default, **Docker runs processes inside containers as the root user**.

#### **Example:**

When you run the following command:

```bash
docker run -it ubuntu bash
```

Inside the container, if you run:

```bash
whoami
```

You'll get:

```bash
root
```

This indicates that the container is running as the root user. However, this can be a **security risk**, especially if the container is compromised, as it may gain escalated privileges on the host.

---

### **1.4. Running Containers as Non-Root Users**

If you **don't want** your container processes to run as root, you can specify a **non-root user**:

#### **Option 1: Using `--user` flag in Docker Run**

```bash
docker run -it --user 1000 ubuntu bash
```

Inside the container, running `whoami` will show a **non-root user**.

#### **Option 2: Defining User in Dockerfile**

You can set the user at the time of building the image:

```dockerfile
FROM ubuntu
USER 1000
```

Then, build and run the image:

```bash
docker build -t custom-ubuntu .
docker run -it custom-ubuntu bash
```

Now the process will run with **User ID 1000** by default.

---

### **1.5. Is Root in the Container Equal to Root on the Host?**

This is a **common misconception**. Just because you're root **inside** a container doesn't mean you have the same privileges as the root **on the host**. Docker uses **Linux Capabilities** to limit what the root user in a container can do.

#### **Linux Capabilities:**

Linux breaks down root privileges into **fine-grained capabilities**. Some of these include:

- **Creating/Killing processes**
- **Setting User IDs (UIDs) and Group IDs (GIDs)**
- **Networking operations** (e.g., binding to privileged ports)
- **System operations** (e.g., rebooting the host)

---

### **1.6. Managing Capabilities in Docker**

By **default**, Docker drops many of these capabilities for containers, making them **less powerful** than the root user on the host.

#### **Adding Capabilities:**

To add capabilities:

```bash
docker run --cap-add=NET_ADMIN ubuntu
```

This gives the container **network administration** capabilities.

#### **Dropping Capabilities:**

To remove capabilities:

```bash
docker run --cap-drop=ALL ubuntu
```

This strips **all capabilities** from the container.

#### **Running in Privileged Mode:**

To grant **full host privileges** to a container:

```bash
docker run --privileged ubuntu
```

This is **dangerous** and should be avoided in production unless absolutely necessary.

---

## **2. SecurityContexts in Kubernetes**

Now that we've covered Docker security, let's explore how Kubernetes handles container security through **SecurityContexts**.

---

### **2.1. What is a SecurityContext in Kubernetes?**

A **SecurityContext** defines **privilege and access control settings** for a **Pod** or **Container** in Kubernetes.

You can specify:

- **User IDs** to run containers
- **Group IDs**
- **Linux capabilities**
- **Privilege escalation settings**
- **Filesystem permissions** (like making root filesystem read-only)

---

### **2.2. Example of SecurityContext in Kubernetes**

#### **Basic Example: Running a Pod as a Non-Root User**

Here's how you can create a **Pod** that runs as a **non-root user**.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: non-root-pod
spec:
  containers:
  - name: ubuntu
    image: ubuntu
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 1000    # Run as non-root user
      runAsGroup: 3000   # Group ID
      fsGroup: 2000      # File system group
```

#### **Explanation:**

- `runAsUser: 1000`: Runs the container process as user ID **1000**.
- `runAsGroup: 3000`: Runs the container process with group ID **3000**.
- `fsGroup: 2000`: Files created by the container will have **group ownership** of **2000**.

---

### **2.3. Adding/Dropping Capabilities in Kubernetes**

Just like in Docker, you can **add** or **drop capabilities** in Kubernetes using the **SecurityContext**.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: capability-pod
spec:
  containers:
  - name: ubuntu
    image: ubuntu
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        add: ["NET_ADMIN"]    # Add network admin capability
        drop: ["ALL"]         # Drop all other capabilities
```

---

### **2.4. Running Privileged Containers in Kubernetes**

If you need to run a **privileged** container:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
spec:
  containers:
  - name: ubuntu
    image: ubuntu
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
```

**Note:** Use this with caution, as it gives the container **full access to the host**.

---

### **2.5. Read-Only Root Filesystem**

You can make the root filesystem **read-only** to enhance security:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: readonly-pod
spec:
  containers:
  - name: ubuntu
    image: ubuntu
    command: ["sleep", "3600"]
    securityContext:
      readOnlyRootFilesystem: true
```

---

## **Conclusion**

- **Docker Security** is foundational to understanding **Kubernetes Security**.
- **Namespaces** isolate processes, while **User IDs** and **Capabilities** control access and privileges.
- **Kubernetes SecurityContext** provides powerful ways to secure containers by controlling **user access**, **capabilities**, and **filesystem permissions**.

By following these best practices, you can ensure your Kubernetes workloads are secure and isolated appropriately.

---

See you in the next lecture, where we'll dive deeper into **PodSecurityPolicies** and how they complement SecurityContexts!
