**Problem Statement: Deploying a Web Application and Configuring Persistent Database in OpenShift/Kubernetes**

In this exercise, you will deploy a web application and its associated database on an OpenShift/Kubernetes cluster, ensuring the application is properly configured with persistent storage and environment variables. The goal is to configure various resources such as projects, secrets, deployments, persistent volumes, services, and routes, while ensuring reproducibility and seamless updates to the deployed services.

### Tasks:

1. **Prepare System Resources**:  
   Use the `lab start compreview-deploy` command to prepare your system for the exercise. This command ensures all necessary resources are available and creates the `/home/student/DO180/labs/compreview-deploy/resources.txt` file containing cluster details and image names.

2. **Create and Configure Project**:
   - Create a project named `review` where all resources will be stored.
   - Configure the project to reference the `mysql8:1` image for the database, pointing to `registry.ocp4.example.com:8443/rhel9/mysql-80:1-228` (ensure the image short name is used).

3. **Create Database Secret**:
   - Create a secret named `dbparams` to store the MySQL database parameters. These parameters should include:
     - `user: operator1`
     - `password: redhat123`
     - `database: quotesdb`
   
4. **Configure Database Deployment**:
   - Create a `quotesdb` deployment using the `mysql8:1` image.
   - Ensure the deployment automatically rolls out if the source container in the `mysql8:1` resource changes.
   - Configure the database with environment variables from the `dbparams` secret:
     - `MYSQL_USER` -> `user`
     - `MYSQL_PASSWORD` -> `password`
     - `MYSQL_DATABASE` -> `database`
   - Ensure data persistence with a volume attached to the `/var/lib/mysql` directory, using the `lvms-vg1` storage class (maximum 2 GiB).

5. **Create Database Service**:
   - Create a service for the database (`quotesdb`), exposing it on port 3306 for communication with the frontend application.

6. **Configure Frontend Deployment**:
   - Create a frontend deployment using the `registry.ocp4.example.com:8443/redhattraining/famous-quotes:2-42` image.
   - Configure the following environment variables for the frontend deployment from the `dbparams` secret:
     - `QUOTES_USER` -> `user`
     - `QUOTES_PASSWORD` -> `password`
     - `QUOTES_DATABASE` -> `database`
     - `QUOTES_HOSTNAME` -> `quotesdb`
   - Expose the frontend deployment so that it can be accessed externally at `http://frontend-review.apps.ocp4.example.com`, listening on port 8000.

7. **Testing Configuration**:
   - Test the setup by modifying the `mysql8:1` image to point to the newer `registry.ocp4.example.com:8443/rhel9/mysql-80:1-237` image and verify the database deployment automatically rolls out.
   - Reset the image back to the original `registry.ocp4.example.com:8443/rhel9/mysql-80:1-228` image before final submission.

### Outcomes:

Upon completing this exercise, you should be able to:

- Create and configure OpenShift/Kubernetes resources such as projects, secrets, deployments, persistent volumes, services, and routes.
- Ensure application deployments are reproducible by using image streams and references to external resources.
- Use Kubernetes secrets to securely manage environment variables for applications.
- Configure persistent storage for applications to maintain data consistency across pod restarts.
- Expose applications externally using routes and services.
