## Init Containers
- In Kubernetes, each pod can have more than one container. These containers within the same pod work together to accomplish a common goal or provide a cohesive set of functionalities.
- There are two types of containers that we can run within a pod: the main containers and the initialization containers (or init containers).
- Init containers are used inside pod specification.
- There is a `containers` field that accepts a list of containers definition for the normal containers and the `initContainers` field that defines the list of initialization containers.
- Despite sharing the same container specification, the init containers do not support the lifecycle, `livenessProbe`, `readinessProbe`, and `startupProbe` fields. Setting values for these fields on init containers is a validation error and will invalidate the whole pod manifest.

## Purpose of Init Containers
- One common use case of the init containers is to run a script that blocks until certain preconditions are true. This is because the init containers will always be the first containers to run within the pods. Additionally, the main container of the pod will not start if the init containers do not complete successfully. For instance, we can ping a dependent service in init containers to make sure it’s alive before we start our main workload in the pod.
- Init containers can also be used to configure the network stack and populate data in the volume for the main workload of the pod. This is possible because containers within the same pod share the same network namespace and volume device. Therefore, changes made by the init containers on the network namespace and volume device will be persisted throughout the whole lifecycle of a single pod.
- For example, the Istio project, a popular open-source service mesh software, uses the init containers mechanism to configure the network stack of the pod as part of the initialization process. Specifically, it deploys an init container to configure the iptables of the pod to intercept all the incoming and outgoing traffic of the main application container.

## Lifecycle of Init Containers
- Creating and running init containers are the first steps for bringing a pod to life. Understanding the lifecycle of the init containers can help in understanding and debugging issues related to the readiness of a pod.
  
###  Starting up the Init Containers
- The process begins when a pod resource is created on the Kubernetes cluster. The creation of the pod can be either directly using the Pod specification or indirectly through the Deployment, StatefulSet, or DaemonSet specification.
- The kube-scheduler will schedule the pod on a node. The kubelet process on the node will create and start the init containers.
- Due to the init containers’ sequential execution order, the process will run the first init container and observe its exit code before deciding on the next step.

### On Init Containers Failure
- When the init container returns a non-zero exit code, the startup process either fails or restarts the process, depending on the restartPolicy of the pod.
- If the `restartPolicy` is set to `Never`, the pod status will change to Failed, and the start-up process stops at this point.
- Alternatively, for the `restartPolicy` value of `Always` or `OnFailure`, the whole process will be restarted, starting from the first init container in the list.
- It’s important to design init containers to be idempotent due to the possibility of multiple executions of init containers because of restarts.
- If there’s a failure in the init containers, the status of the pod will turn to `Init:Error`, indicating that the pod failed to start due to errors in the init containers.
- When the same error occurs multiple times, the status will change to `Init:CrashedLoopBackOff`.

### On Init Containers Success
- A zero exit code of an init container signifies that the initialization task is successful.
- The pod start-up process proceeds to the next init container in the list.
- The kubelet process will update the status of the pod to `Init:N/M`, where N is the number of init containers that have succeeded, and M is the total number of init containers defined.
- This process continues until all the init containers run to completion with a zero exit code.
- When all the init containers have been completed successfully, the pod status will be set to `PodInitializing`.
- Beyond this point, the responsibility of the init containers officially ends, and the main containers' startup process will begin.
