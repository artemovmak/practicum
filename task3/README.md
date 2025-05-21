# Prometheus Monitoring Integration

This solution implements Prometheus monitoring for the Kubernetes system with Istio service mesh.

## Components

1. **Modified Application (`app/app.py`)**:
   - Added Prometheus metrics endpoint at `/metrics`
   - Implemented counters for `/log` endpoint calls (total, success, failure)
   - Added request duration histogram for performance monitoring
   - Exposed metrics in Prometheus format

2. **Prometheus Deployment**:
   - Uses `kube-prometheus-stack` Helm chart
   - Custom configuration in `prometheus-values.yaml`
   - Automatic service discovery for Kubernetes pods
   - Specific scraping configuration for Istio metrics

3. **Kubernetes Manifests**:
   - Updated deployment with Prometheus annotations
   - Added ServiceMonitor custom resource for Prometheus Operator
   - Health and readiness probes for better monitoring

4. **Deployment Script (`deploy.sh`)**:
   - Installs and configures Istio service mesh
   - Sets up Prometheus monitoring stack
   - Deploys application and monitoring components
   - Provides convenient access to dashboards

## Metrics Available

1. **Custom Application Metrics**:
   - `log_requests_total`: Counter of total `/log` endpoint calls
   - `log_requests_success`: Counter of successful `/log` endpoint calls
   - `log_requests_failure`: Counter of failed `/log` endpoint calls
   - `app_request_duration_seconds`: Histogram of request processing times

2. **Istio Metrics**:
   - `istio_requests_total`: Total count of requests across the mesh
   - `istio_request_duration_seconds`: Request duration in Istio
   - `istio_response_bytes`: Size of the HTTP response

3. **System Metrics**:
   - Standard Kubernetes metrics via kube-state-metrics
   - Node metrics via node-exporter

## How to Use

1. Prerequisites:
   - Kubernetes cluster
   - kubectl, istioctl, and helm installed
   - Docker for building the application image

2. Run the deployment script:
   ```
   ./deploy.sh
   ```

3. Access Prometheus dashboard:
   ```
   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
   ```
   Then open `http://localhost:9090` in your browser

4. Access Grafana dashboard:
   ```
   kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
   ```
   Then open `http://localhost:3000` in your browser
   Use `admin / admin` credentials

5. Suggested Prometheus queries:
   - `log_requests_total`: Total number of log requests
   - `rate(app_request_duration_seconds_count[5m])`: Request rate by endpoint
   - `histogram_quantile(0.95, sum(rate(app_request_duration_seconds_bucket[5m])) by (endpoint, le))`: 95th percentile latency by endpoint
   - `istio_requests_total{destination_service="custom-app-service.default.svc.cluster.local"}`: Istio-tracked requests to the app 