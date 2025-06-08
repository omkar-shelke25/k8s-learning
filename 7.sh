#!/bin/bash

mkdir -p k8s-manifests

# 1. Secret for MongoDB URIs
cat <<EOF > k8s-manifests/mongodb-uri-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-uri-secret
type: Opaque
stringData:
  USER_DB_URI: mongodb://mongodb:27017/user_db
  ORDER_DB_URI: mongodb://mongodb:27017/order_db
  PAYMENT_DB_URI: mongodb://mongodb:27017/payment_db
EOF

# 2. MongoDB PVC
cat <<EOF > k8s-manifests/mongodb-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongodb-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# 3. MongoDB Deployment & Service
cat <<EOF > k8s-manifests/mongodb.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
        - name: mongodb
          image: mongo:7.0
          ports:
            - containerPort: 27017
          volumeMounts:
            - name: mongo-storage
              mountPath: /data/db
      volumes:
        - name: mongo-storage
          persistentVolumeClaim:
            claimName: mongodb-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb
spec:
  selector:
    app: mongodb
  ports:
    - port: 27017
      targetPort: 27017
EOF

# 4. User Service
cat <<EOF > k8s-manifests/user-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
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
          image: omkara25/simple-microservice-app-user-service:v1
          ports:
            - containerPort: 8001
          env:
            - name: MONGODB_URI
              valueFrom:
                secretKeyRef:
                  name: mongodb-uri-secret
                  key: USER_DB_URI
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
spec:
  selector:
    app: user-service
  ports:
    - port: 8001
      targetPort: 8001
EOF

# 5. Order Service
cat <<EOF > k8s-manifests/order-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
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
          image: omkara25/simple-microservice-app-order-service:v1
          ports:
            - containerPort: 8002
          env:
            - name: MONGODB_URI
              valueFrom:
                secretKeyRef:
                  name: mongodb-uri-secret
                  key: ORDER_DB_URI
            - name: USER_SERVICE_URL
              value: http://user-service:8001
---
apiVersion: v1
kind: Service
metadata:
  name: order-service
spec:
  selector:
    app: order-service
  ports:
    - port: 8002
      targetPort: 8002
EOF

# 6. Payment Service
cat <<EOF > k8s-manifests/payment-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
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
          image: omkara25/simple-microservice-app-payment-service:v1
          ports:
            - containerPort: 8003
          env:
            - name: MONGODB_URI
              valueFrom:
                secretKeyRef:
                  name: mongodb-uri-secret
                  key: PAYMENT_DB_URI
            - name: ORDER_SERVICE_URL
              value: http://order-service:8002
---
apiVersion: v1
kind: Service
metadata:
  name: payment-service
spec:
  selector:
    app: payment-service
  ports:
    - port: 8003
      targetPort: 8003
EOF

echo "✅ All K8s manifests generated in 'k8s-manifests/' (no Operator used)."
