# Распределённая система логирования в Kubernetes


## Компоненты

1.  **Custom Web App (`custom-app`)**: Веб-приложение на Flask (Python), которое:
    * Предоставляет эндпоинты: `/`, `/status`, `/log` (POST), `/logs` (GET).
    * Пишет логи в файл `/app/logs/app.log`.
    * Конфигурируется через ConfigMap (порт, уровень лога, заголовок).
2.  **Deployment (`custom-app-deployment`)**: Управляет 3 репликами веб-приложения.
    * Использует `hostPath` для сохранения логов на узле (`/var/log/custom-app`), чтобы DaemonSet мог их прочитать.
    * Монтирует ConfigMap для конфигурации.
3.  **Service (`custom-app-service`)**: `ClusterIP` сервис для балансировки нагрузки между подами приложения.
4.  **DaemonSet (`log-agent`)**: Запускает на каждом узле под-агент (`busybox` с `tail`), который:
    * Монтирует ту же директорию `hostPath` (`/var/log/custom-app`), что и приложение.
    * Читает файл `app.log` и выводит его содержимое в свой `stdout`.
5.  **CronJob (`log-archiver`)**: Запускается каждые 10 минут:
    * Получает содержимое логов через API приложения (`http://custom-app-service/logs`).
    * Создает `tar.gz` архив логов в `/tmp` внутри своего контейнера.
6.  **ConfigMap (`custom-app-config`)**: Хранит конфигурацию для веб-приложения.


## Сборка образа приложения (если необходимо)

1.  Перейдите в корневую директорию проекта.
2.  Выполните команду сборки:
    ```bash
    docker build -t custom-app:v1 .
    ```
3.  (Опционально) Если ваш кластер не имеет прямого доступа к локальным образам Docker (например, это не Minikube), загрузите образ в ваш репозиторий:
    ```bash
    docker tag custom-app:v1 your-repo/custom-app:v1
    docker push your-repo/custom-app:v1
    ```
    *Не забудьте обновить имя образа в `k8s/deployment.yaml`*.

## Развертывание

1.  Убедитесь, что директория `hostPath` (`/var/log/custom-app` по умолчанию) существует на узлах вашего кластера, где могут быть запущены поды приложения.
2.  Перейдите в корневую директорию проекта.
3.  Запустите скрипт развертывания:
    ```bash
    ./deploy.sh
    ```
    Скрипт применит все необходимые Kubernetes манифесты из папки `k8s/` и дождется готовности Deployment и DaemonSet.

## Проверка работы

* **Проверить приложение через Service (изнутри кластера):**
    ```bash
    kubectl run curl-test --image=curlimages/curl -it --rm -- sh
    # Внутри пода:
    curl http://custom-app-service/
    curl http://custom-app-service/status
    curl -X POST http://custom-app-service/log -H "Content-Type: application/json" -d '{"message": "Hello from test pod"}'
    curl http://custom-app-service/logs
    exit
    ```
* **Проверить логи, собранные агентами:**
    ```bash
    # Показать логи со всех агентов
    kubectl logs -l app=log-agent --tail=50

    # Следить за логами одного из агентов
    AGENT_POD=$(kubectl get pods -l app=log-agent -o jsonpath='{.items[0].metadata.name}')
    kubectl logs -f $AGENT_POD
    ```
* **Проверить работу CronJob:**
    ```bash
    # Показать статус CronJob
    kubectl get cronjob log-archiver

    # Показать задачи (jobs), созданные CronJob
    kubectl get jobs --sort-by=.metadata.creationTimestamp

    # Посмотреть логи последней завершенной задачи архивации
    JOB_NAME=$(kubectl get jobs -l cronjob-name=log-archiver --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}')
    ARCHIVER_POD=$(kubectl get pods -l job-name=$JOB_NAME -o jsonpath='{.items[0].metadata.name}')
    kubectl logs $ARCHIVER_POD
    ```
