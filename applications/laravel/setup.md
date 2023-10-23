<p align="center"><a href="https://laravel.com" target="_blank"><img src="https://raw.githubusercontent.com/laravel/art/master/logo-lockup/5%20SVG/2%20CMYK/1%20Full%20Color/laravel-logolockup-cmyk-red.svg" width="400" alt="Laravel Logo"></a></p>

<p align="center">
<a href="https://github.com/laravel/framework/actions"><img src="https://github.com/laravel/framework/workflows/tests/badge.svg" alt="Build Status"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/dt/laravel/framework" alt="Total Downloads"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/v/laravel/framework" alt="Latest Stable Version"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/l/laravel/framework" alt="License"></a>
</p>

## Setup Laravel on Kubernetes

### Prerequisites
1. Laravel Project.
2. Kubernetes Cluster.
3. Redis.
4. Helm.

This article assumes you already have a Laravel project and the example of this deploying is on Laravel version 8. If you have a different Laravel version then you will need to modify and change the dockerfile below for the backend.

This example of a project is running on MySQL database, if you have a different database you will need to modify the dockerfile of the backend to install the dependent packages for your database.

We will use the Helm chart to install MySQL and Redis on the k8s cluster, which is the most recommended way to deploy these services.


### Setup Redis on laravel
To configure your Laravel app to start storing session information on Redis, from the config/session.php file change the following

```
'driver' => env('SESSION_DRIVER', 'file'),
```
to
```
'driver' => env('SESSION_DRIVER', 'redis'),
```
Then execute the following composer command to add the predis package to the composer.json file.
```
composer require predis/predis
```

### Dockerize Laravel
Before start creating the Dockerfile let's explain what we will do to dockerize the application.

We will create two containers, one for the backend which will contain the controllers and routes, and the other for the frontend which will include the public directory.

All the requests will go to the frontend container, there is an Nginx proxy in the frontend container that will forward the requests to the backend if the request requires communication with the backend.

Let’s create a directory with the name docker in your project path to contain the dockerfiles.

```
mkdir ./docker
```

#### Frontend Dockerfile
```
touch ./docker/nginx.Dockerfile
```
below is the content of nginx.Dockerfile

```
FROM node:15.5-alpine AS assets-build
WORKDIR /var/www/html
COPY . /var/www/html/

RUN npm ci
RUN npm run development

FROM nginx:1.19-alpine AS nginx
COPY /docker/vhost.conf /etc/nginx/conf.d/default.conf
COPY --from=assets-build /var/www/html/public /var/www/html/
```

<b>Note:</b> if your application is not using any frontend frameworks and isn't required to install any Javascript packages with npm, remove the two lines of npm in the dockerfile.

Create the Nginx proxy config file in the same docker directory.

```
touch ./docker/vhost.conf
```

below is the content of vhost.conf file

```
server {
    listen  80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;

    index /public/index.php;
    error_page 404 /public/index.php;

    location / {
        try_files $uri $uri/ /public/index.php;
    }

    location ~ \.php$ {
        fastcgi_pass localhost:9000;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param SCRIPT_NAME $fastcgi_script_name;
    }
}
```

#### Backend Dockerfile
Create Dockerfile for the backend first.

```
touch ./docker/fpm.Dockerfile
```

below is the content of fpm.Dockerfile

```
FROM php:8.0-fpm-alpine AS base
ENV EXT_APCU_VERSION=master
RUN curl -vvv https://github.com/krakjoe/apcu.git

RUN apk add --update zlib-dev libpng-dev libzip-dev $PHPIZE_DEPS

RUN docker-php-ext-install exif
RUN docker-php-ext-install gd
RUN docker-php-ext-install zip
RUN docker-php-ext-install pdo_mysql
# RUN pecl install apcu
RUN docker-php-source extract \
    && apk -Uu add git \
    && git clone --branch $EXT_APCU_VERSION --depth 1 https://github.com/krakjoe/apcu.git /usr/src/php/ext/apcu \
    && cd /usr/src/php/ext/apcu && git submodule update --init \
    && docker-php-ext-install apcu
RUN docker-php-ext-enable apcu

FROM base AS dev

COPY /composer.json composer.json
COPY /composer.lock composer.lock
COPY /app app
COPY /bootstrap bootstrap
COPY /config config
COPY /artisan artisan

FROM base AS build-fpm

WORKDIR /var/www/html

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY /artisan artisan
COPY . /var/www/html
# COPY /composer.json composer.json

RUN composer install --prefer-dist --no-ansi --no-dev --no-autoloader

COPY /bootstrap bootstrap
COPY /app app
COPY /config config
COPY /routes routes


# COPY . /var/www/html

RUN composer dump-autoload -o

FROM build-fpm AS fpm

COPY --from=build-fpm /var/www/html /var/www/html
```

The Dockerfile wrote with PHP 8.0 which could your application build with a different PHP version and will cost errors like not compatible versions. In this case, you have to change the image version in the first line in dockerfile and make sure the image type is fpm-alpine.

See here for more PHP images version.

#### Build the Dockerfile.

<b>Note:</b> make sure you are in the project directory before executing the docker build command.

Building the frontend image

```
docker build . -f docker/nginx.Dockerfile -t frontend
```

Building the backend image

```
docker build . -f docker/fpm.Dockerfile -t backend
```

After building the images now we are ready to move deploy on Kubernetes.


### Helm Chart: Setup MySQL and Redis
Before start creating the k8s manifest files. We need MySQL and Redis running on the cluster first so I will use the Helm chart for that.

Make sure you have Helm installed on your machine, then execute the following command to add bitnami repo.

```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

Start installing MySQL by using Helm chart.

In the command of installing you will provide the database name, database user, and database password, this information will be used in configuring and secret of deployment.

```
helm install mysql bitnami/mysql --set auth.database="application" --set auth.username="ahmed" --set auth.password="sqlhardPass123"
```

Installing Redis using Helm chart, make sure to save the Redis password which is provided on the command while installing.

```
helm install redis bitnami/redis --set auth.password="rdshardPass123"
```

Check the status of the MySQL & Redis pods, should be running both.

```
kubectl get pod
```
If both are running now you are ready to start creating the Kubernetes manifest files.


### Config File

```
mkdir ./k8s
```

Create the config file for the deployment.

```
touch ./k8s/app_config.yaml
```

Below is the content of app_config.yaml file

```
apiVersion: v1
kind: ConfigMap
metadata:
  name: application-config
data:
  APP_NAME: test-app
  APP_ENV: production
  APP_DEBUG: "false"
  APP_URL: http://localhost:8080
  LOG_CHANNEL: stack
  LOG_LEVEL: debug
  DB_CONNECTION: mysql
  DB_HOST: mysql
  DB_PORT: "3306"
  DB_DATABASE: application
  DB_USERNAME: ahmed
  BROADCAST_DRIVER: log
  CACHE_DRIVER: redis
  QUEUE_CONNECTION: sync
  SESSION_DRIVER: redis
  SESSION_LIFETIME: "120"
  PROMETHEUS_NAMESPACE: default
  PROMETHEUS_METRICS_ROUTE_ENABLED: "true"
  PROMETHEUS_METRICS_ROUTE_PATH: metrics
  PROMETHEUS_METRICS_ROUTE_MIDDLEWARE: "null"
  PROMETHEUS_STORAGE_ADAPTER: memory
  REDIS_HOST: redis-master
  REDIS_PORT: "6379"
  REDIS_CLIENT: "predis"
  PROMETHEUS_REDIS_PREFIX: PROMETHEUS_
```

Make sure to write the correct DB_HOST, DB_USERNAME, and REDIS_HOST which is what you provide while running the helm install MySQL & Redis command.

### Secret File
Let’s create the secret file first

```
touch ./k8s/app_secret.yaml
```

below is the content of app_secret.yaml file

```
apiVersion: v1
kind: Secret
metadata: 
    name: application-secret
type: Opaque
data:
   REDIS_PASSWORD: cmRzaGFyZFBhc3MxMjM=
   DB_PASSWORD: c3FsaGFyZFBhc3MxMjM=
   APP_KEY: YmFzZTY0OnhwVDVZWkdtZWZ1TXFqVmlIODVxTE15cGxNR244WXhoQkVGcGMrVElKbTQ9
```

Notes the <b>REDIS_PASSWORD & DB_PASSWORD</b> are what you provided while installing with the Helm chart, and are encoded by base64.

About <b>APP_KEY</b> you can generate your Laravel app key then encode it by base64 and replace it with one that exists.


### Deployment File
The deployment file will contain two containers one for the backend and the other for the frontend, also will contain initContiner which will use the same backend image and will execute the php migration command to get the database ready.

Create the deployment file

```
touch ./k8s/app_deployment.yaml
```

Below is the content of app_deployment.yaml file

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-application
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-application
  template:
    metadata:
      labels:
        app: web-application
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/path: /metrics
        prometheus.io/port: "80"
    spec:
      volumes:
        - name: logs
          emptyDir: {}
        - name: views
          emptyDir: {}
      securityContext:
        fsGroup: 82
      initContainers:
        - name: database-migrations
          image: backend
          imagePullPolicy: IfNotPresent
          envFrom:
            - configMapRef:
                name: application-config
            - secretRef:
                name: application-secret
          command:
            - "php"
          args:
            - "artisan"
            - "migrate"
            - "--force"
      containers:
        - name: nginx
          imagePullPolicy: IfNotPresent
          image: frontend
          resources: {}
            # limits:
            #   cpu: 500m
            #   memory: 50M
          ports:
            - containerPort: 80
        - name: fpm
          imagePullPolicy: IfNotPresent
          envFrom:
            - configMapRef:
                name: application-config
            - secretRef:
                name: application-secret
          securityContext:
            runAsUser: 82
            readOnlyRootFilesystem: true
          volumeMounts:
            - name: logs
              mountPath: /var/www/html/storage/logs
            - name: views
              mountPath: /var/www/html/storage/framework/views
          resources: {}
          image: backend
          ports:
            - containerPort: 9000
```

Make sure to write the right images name in the deployment file.

### Service File
The last required file is to create a service to expose the application, for the best practice it’s recommended to create a service and ingress, but for this example, I will go with service type nodePort only without creating ingress.

to create the service file execute the following.

```
touch ./k8s/app_service.yaml
```

below is the content of app_service.yaml file

```
apiVersion: v1
kind: Service
metadata:
  labels:
    app: web-application-svc
  name: web-application-svc
spec:
  type: NodePort
  selector:
    app: web-application
  ports:
  - name: targetport
    port: 80
    protocol: TCP
    targetPort: 80
    nodePort: 30007
```

### Apply the Manifest
Start applying the k8s manifest files.

```
kubectl apply -f ./k8s/app_config.yaml
kubectl apply -f ./k8s/app_secret.yaml
kubectl apply -f ./k8s/app_deployment.yaml
kubectl apply -f ./k8s/app_service.yaml
```

Check the status of pods

```
kubectl get pod
```

If the pod gets an error or isn’t ready, check the logs of the pod by specifying the container name, below is an example of a logs command

```
kubectl logs pod <pod_Name> -c database-migrations
kubectl logs pod <pod_Name> -c nginx
kubectl logs pod <pod_Name> -c fpm
```

Or you can describe the pod to see more details for troubleshooting.

```
kubectl describe pod <pod_Name>
```

### Conclusion
Deploying a Laravel application on Kubernetes provides a modern, efficient, and scalable approach to managing and running web applications. While the initial setup and configuration may require some learning, the benefits in terms of reliability, scalability, and DevOps practices make it a worthwhile investment for both small-scale and large-scale Laravel projects.
