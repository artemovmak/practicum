# Интеграция мониторинга Prometheus

Данное решение реализует мониторинг Prometheus для Kubernetes-системы с сервисной сеткой Istio.

## Компоненты

1. **Модифицированное приложение (`app/app.py`)**:
   - Добавлена конечная точка для метрик Prometheus по пути `/metrics`
   - Реализованы счетчики вызовов конечной точки `/log` (общее количество, успешные, неудачные)
   - Добавлена гистограмма длительности запросов для мониторинга производительности
   - Метрики предоставляются в формате Prometheus

2. **Развертывание Prometheus**:
   - Использует Helm-чарт `kube-prometheus-stack`
   - Пользовательская конфигурация в `prometheus-values.yaml`
   - Автоматическое обнаружение сервисов в Kubernetes
   - Специальная конфигурация для сбора метрик Istio

3. **Манифесты Kubernetes**:
   - Обновленный deployment с аннотациями для Prometheus
   - Добавлен ресурс ServiceMonitor для оператора Prometheus
   - Пробы здоровья и готовности для лучшего мониторинга

4. **Скрипт развертывания (`deploy.sh`)**:
   - Устанавливает и настраивает сервисную сетку Istio
   - Настраивает стек мониторинга Prometheus
   - Разворачивает приложение и компоненты мониторинга
   - Предоставляет удобный доступ к дашбордам

## Доступные метрики

1. **Метрики пользовательского приложения**:
   - `log_requests_total`: Счетчик общего количества вызовов конечной точки `/log`
   - `log_requests_success`: Счетчик успешных вызовов конечной точки `/log`
   - `log_requests_failure`: Счетчик неудачных вызовов конечной точки `/log`
   - `app_request_duration_seconds`: Гистограмма времени обработки запросов

2. **Метрики Istio**:
   - `istio_requests_total`: Общее количество запросов в сервисной сетке
   - `istio_request_duration_seconds`: Длительность запросов в Istio
   - `istio_response_bytes`: Размер HTTP-ответа

3. **Системные метрики**:
   - Стандартные метрики Kubernetes через kube-state-metrics
   - Метрики узлов через node-exporter

## Как использовать

1. Предварительные требования:
   - Кластер Kubernetes
   - Установленные kubectl, istioctl и helm
   - Docker для сборки образа приложения

2. Запустите скрипт развертывания:
   ```
   ./deploy.sh
   ```

3. Доступ к дашборду Prometheus:
   ```
   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
   ```
   Затем откройте `http://localhost:9090` в браузере

4. Доступ к дашборду Grafana:
   ```
   kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
   ```
   Затем откройте `http://localhost:3000` в браузере
   Используйте учетные данные: `admin / admin`

5. Рекомендуемые запросы Prometheus:
   - `log_requests_total`: Общее количество запросов логирования
   - `rate(app_request_duration_seconds_count[5m])`: Частота запросов по конечным точкам
   - `histogram_quantile(0.95, sum(rate(app_request_duration_seconds_bucket[5m])) by (endpoint, le))`: 95-й процентиль задержки по конечным точкам
   - `istio_requests_total{destination_service="custom-app-service.default.svc.cluster.local"}`: Запросы к приложению, отслеживаемые Istio 
