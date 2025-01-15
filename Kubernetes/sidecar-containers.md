### Sidecar Containers
- A **sidecar container** is a design pattern that allows you to run an additional container alongside your main container in the same pod. The sidecar container can perform tasks that complement the main container, such as syncing data from a remote source, collecting and shipping logs, providing health checks and metrics, proxying network traffic, encrypting or decrypting data, or injecting faults for testing.
- **Sidecar containers** are secondary containers that run alongside the main application container within the same **Pod**. These containers extend the functionality of the primary application by providing additional services, such as logging, monitoring, security, or data synchronization, without modifying the main application's code.

- A common use case for sidecar containers is to sync data from a remote source to a local volume that is shared with the main container, such as configuration files, secrets, or certificates.

- To implement sidecar containers in Kubernetes, you define a **Pod** with multiple containers that share the same lifecycle, resources, and network namespace but have separate file systems and process spaces. Below is an example:

---

### Lifecycle of Sidecar
- One important requirement of a sidecar is that its lifecycle has to be tightly coupled with the main application’s lifecycle. In other words, the sidecar container should startup, shut down, and scale with the main container.

- The sidecar will only serve the main application, and its lifecycle starts and ends with the main application’s lifecycle.

--- 
### Communication Between Containers
- The containers within a single pod share the network namespace. Therefore, the sidecar container can communicate with the main application container through localhost. One downside is that the sidecar container and the main application container must not listen on the same port. This is because only a single process can listen to the same port on the same network namespace.

- Another way for the sidecar container to interact with the main application container is by writing to the same volume. One way to share volume between containers in the same pod is by using the emptyDir volume. The emptyDir volume is created when a pod is created, and all the containers within the same pod can read from and write to that volume. However, the content of the emptyDir is ephemeral by nature and is erased when the pod is deleted.

- For example, we can run a log shipper container alongside our main application container. The main application container will write the logs to the emptyDir volume and the log shipper container will tail the logs and ship them to a remote target.


---

### Lifecycle Issue of a Sidecar Container
There are some caveats we have to take note of when implementing a sidecar container in Kubernetes. Specifically, the issues stem from the fact that Kubernetes doesn’t differentiate between containers in the pod. In other words, there’s no concept of primary or secondary containers in the Kubernetes perspective.

#### Non-Sequential Starting Order
- **When a pod starts, the kubelet process starts all the containers concurrently. Additionally, we cannot control the sequence of containers starting.** For cases that require the sidecar container to be ready first before the main application container, this can be problematic. Some workarounds include adding a custom delay timer on the main application container to delay its starting. However, the best solution is to design the containers to be independent of the starting sequence.

- If we require some initialization work prior to the main application starting, we should use the initContainers. This is because they are different from the normal containers in that they’ll always run to completion first before Kubernetes starts the main containers.

#### Preventing a Job From Completion
- The Job object in Kubernetes is a specialized workload that is similar to a Deployment. However, one crucial difference is that the expectation of a Job object is to run to completion.

- **If we add a long-running sidecar container, the Job object will never reach the completion state.** This is because Kubernetes will only consider a Job as complete when all of its containers exit with a zero exit code.

- Besides that, it will also cause a Job that configures the deadline using the activeDeadlineSeconds property to timeout and restart. This can be problematic if we have a process that depends on the completion state of the Job object.

- **One solution is to extend the main application container in the Job to send a SIGTERM to the sidecar containers prior to exit**. This can ensure that the sidecar container will shut down when the main application exits, completing the Job object.



#### Kubernetes Manifest Example

```yaml
# writing to the same volume
apiVersion: v1
kind: Pod
metadata:
  name: my-app-with-sidecar
  labels:
    app: my-app
spec:
  containers:
    # Main application container
    - name: main-app
      image: nginx:latest
      command: ['sh', '-c', 'while true; do echo $(date) >> /data/t.txt; sleep 1; done']
      volumeMounts:
        - name: shared-logs
          mountPath: /data
    # Sidecar container for logging
    - name: sidecar-logger
      image: busybox:latest
      command: ["/bin/sh", "-c"]
      args: ["while true; do cat /data/t.txt; done"]
      volumeMounts:
        - name: shared-logs
          mountPath: /data
  volumes:
    - name: shared-logs
      emptyDir: {}
```

---

#### Explanation of the Example

1. **Pod Definition**:  
   The Pod is named `my-app-with-sidecar` and labeled as `app: my-app` for easy identification.

2. **Main Application Container**:  
   - **Name**: `main-app`.  
   - **Image**: `nginx:latest`, which is the base image used for the container.  
   - **Command**: Writes the current timestamp to a file (`/data/t.txt`) every second using a shell script.  
   - **Volume Mount**: Mounts the shared volume `shared-logs` at `/data`, enabling both containers to access this directory.

3. **Sidecar Container**:  
   - **Name**: `sidecar-logger`.  
   - **Image**: `busybox:latest`, a minimalistic image commonly used for lightweight tasks.  
   - **Command and Args**: Reads and outputs the content of the shared file (`/data/t.txt`) continuously.  
   - **Volume Mount**: Also mounts the shared volume `shared-logs` at `/data`, allowing access to the same file written by the `main-app` container.

4. **Shared Volume**:  
   - An `emptyDir` volume named `shared-logs` is used to share data between the two containers. This directory exists as long as the Pod is running.

---

### How It Works

- The **main-app** container writes logs (timestamps) to the shared directory (`/data/t.txt`) every second.
- The **sidecar-logger** container reads and displays the logs from the same file, effectively acting as a real-time logger for the main container.


