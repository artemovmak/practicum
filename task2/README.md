# Istio Integration with Kubernetes System

This solution implements Istio service mesh integration with the existing Kubernetes system.

## Components

1. **Istio Gateway (`gateway.yaml`)**: 
   - Accepts HTTP traffic on port 80
   - Entry point for all external requests

2. **Virtual Service (`virtualservice.yaml`)**:
   - Routes traffic to the custom application
   - Special handling for `/log` endpoint with fault injection
   - Returns 404 for all unknown routes

3. **Destination Rules**:
   - `destinationrule.yaml`: Configuration for the main application
   - `log-destinationrule.yaml`: Configuration for the log agent
   - Both use:
     - LEAST_CONN load balancing
     - Connection limits (3 TCP connections, 5 pending HTTP requests)
     - ISTIO_MUTUAL TLS mode

4. **Deployment Script (`deploy.sh`)**:
   - Installs and configures Istio in the cluster
   - Enables automatic sidecar injection
   - Applies all Kubernetes and Istio resources

## Features Implemented

1. **External Traffic Access**:
   - Traffic enters through Istio Gateway on port 80

2. **Traffic Routing**:
   - Main routes directed to the custom-app-service
   - Unknown routes return 404 error

3. **Connection Management**:
   - Load balancing with LEAST_CONN algorithm
   - Connection limits to prevent overload

4. **Fault Tolerance Testing**:
   - 2-second delay added to `/log` endpoint
   - 1-second timeout to force timeout errors
   - Up to 2 retries for failed requests

5. **Secure Communication**:
   - Mutual TLS between services using Istio's built-in security

## How to Use

1. Make sure you have `kubectl` and `istioctl` installed.
2. Run the deployment script:
   ```
   ./deploy.sh
   ```
3. Access the application through the Istio ingress gateway:
   ```
   kubectl get svc istio-ingressgateway -n istio-system
   ```
4. Use the external IP to access the application:
   ```
   http://<EXTERNAL-IP>/
   ```
5. Test the fault injection on the log endpoint:
   ```
   http://<EXTERNAL-IP>/log
   ``` 