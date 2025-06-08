Thanks for sharing the details. Let's break this into two parts:


---

✅ Part 1: Install MongoDB Community Operator on Kubernetes

You can install the MongoDB Community Operator using the following commands:

kubectl create namespace mongodb
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/crd/bases/mongodbcommunity.mongodb.com_mongodbcommunity.yaml
kubectl apply -k "github.com/mongodb/mongodb-kubernetes-operator/config/default?ref=master" -n mongodb

To verify:

kubectl get pods -n mongodb
kubectl get crds | grep mongodb


---

✅ Part 2: Kubernetes YAML (Based on Your Docker Compose)

Below are the Kubernetes files including:

MongoDB Operator Custom Resource

Deployments & Services for: user-service, order-service, payment-service

Namespace: microservices

Network: Assumed managed by K8s networking (no Docker bridge needed)



---

1. MongoDB Custom Resource (mongo.yaml)

apiVersion: mongodbcommunity.mongodb.com/v1
kind: MongoDBCommunity
metadata:
  name: mongodb
  namespace: microservices
spec:
  members: 1
  type: ReplicaSet
  version: "7.0.0"
  security:
    authentication:
      modes: ["SCRAM"]
  users:
    - name: micro_user
      db: user_db
      passwordSecretRef:
        name: mongodb-user-password
      roles:
        - db: user_db
          role: readWrite
  statefulSet:
    spec:
      volumeClaimTemplates:
        - metadata:
            name: data-volume
          spec:
            accessModes: [ "ReadWriteOnce" ]
            resources:
              requests:
                storage: 1Gi

> Create secret for Mongo password:



kubectl create secret generic mongodb-user-password --from-literal=password=YourSecurePass -n microservices


---

2. Deployment for User Service

apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: microservices
spec:
  replicas: 1
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
    spec:
      containers:
        - name: user-service
          image: omkara25/simple-microservice-app-user-service
          ports:
            - containerPort: 8001
          env:
            - name: MONGODB_URI
              value: "mongodb://micro_user:YourSecurePass@mongodb-svc.microservices.svc.cluster.local:27017/user_db"
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: microservices
spec:
  selector:
    app: user-service
  ports:
    - port: 8001
      targetPort: 8001


---

3. Deployment for Order Service

apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: microservices
spec:
  replicas: 1
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
    spec:
      containers:
        - name: order-service
          image: omkara25/simple-microservice-app-order-service
          ports:
            - containerPort: 8002
          env:
            - name: MONGODB_URI
              value: "mongodb://micro_user:YourSecurePass@mongodb-svc.microservices.svc.cluster.local:27017/order_db"
            - name: USER_SERVICE_URL
              value: "http://user-service:8001"
---
apiVersion: v1
kind: Service
metadata:
  name: order-service
  namespace: microservices
spec:
  selector:
    app: order-service
  ports:
    - port: 8002
      targetPort: 8002


---

4. Deployment for Payment Service

apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: microservices
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payment-service
  template:
    metadata:
      labels:
        app: payment-service
    spec:
      containers:
        - name: payment-service
          image: omkara25/simple-microservice-app-payment-service
          ports:
            - containerPort: 8003
          env:
            - name: MONGODB_URI
              value: "mongodb://micro_user:YourSecurePass@mongodb-svc.microservices.svc.cluster.local:27017/payment_db"
            - name: ORDER_SERVICE_URL
              value: "http://order-service:8002"
---
apiVersion: v1
kind: Service
metadata:
  name: payment-service
  namespace: microservices
spec:
  selector:
    app: payment-service
  ports:
    - port: 8003
      targetPort: 8003


---

✅ Create Namespace First

apiVersion: v1
kind: Namespace
metadata:
  name: microservices


---

Let me know if you want:

Ingress setup for these services.

MongoDB access with a GUI (e.g., Mongo Express).

Helm chart for this entire setup.

Auto-scaling or production-grade resources.


I can generate everything in one zip.

