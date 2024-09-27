# Default values for kuberay-operator.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.
SynthoLicense: "{{ LICENSE_KEY }}"

clustername: ray-cluster

imagePullSecrets:
  - name: {{ IMAGE_PULL_SECRET }}

operatorImage:
  repository: {{ RAY_OPERATOR_IMG_REPO }}
  tag: {{ RAY_OPERATOR_IMG_TAG }}
  pullPolicy: IfNotPresent

image:
  # replace them if it is being tested on ARM chip
  # repository: rayproject/ray
  # tag: latest-py310-cpu-aarch64
  repository: {{ RAY_IMAGE_IMG_REPO }}
  tag: {{ RAY_IMAGE_IMG_TAG }}
  pullPolicy: IfNotPresent

head:
  # If enableInTreeAutoscaling is true, the autoscaler sidecar will be added to the Ray head pod.
  # Ray autoscaler integration is supported only for Ray versions >= 1.11.0
  # Ray autoscaler integration is Beta with KubeRay >= 0.3.0 and Ray >= 2.0.0.
  # enableInTreeAutoscaling: true
  # autoscalerOptions is an OPTIONAL field specifying configuration overrides for the Ray autoscaler.
  # The example configuration shown below below represents the DEFAULT values.
  # autoscalerOptions:
    # upscalingMode: Default
    # idleTimeoutSeconds: 60
    # securityContext: {}
    # env: []
    # envFrom: []
    # resources specifies optional resource request and limit overrides for the autoscaler container.
    # For large Ray clusters, we recommend monitoring container resource usage to determine if overriding the defaults is required.
    # resources:
    #   limits:
    #     cpu: "500m"
    #     memory: "512Mi"
    #   requests:
    #     cpu: "500m"
    #     memory: "512Mi"
  init_container_enabled: true
  initContainer:
    arguments: ["chmod", "-R", "777", "/tmp/ray-workflows", "/tmp/ray-data"]
    securityContext: {}
    image: {{ BUSYBOX_IMG_REPO }}:{{ BUSYBOX_IMG_TAG }}
  labels: {}
  rayStartParams:
    dashboard-host: '0.0.0.0'
    block: 'true'
  # containerEnv specifies environment variables for the Ray container,
  # Follows standard K8s container env schema.
  containerEnv:
  - name: RAY_SCHEDULER_SPREAD_THRESHOLD
    value: "0.0"
  envFrom: []
    # - secretRef:
    #     name: my-env-secret
  # ports optionally allows specifying ports for the Ray container.
  # ports: []
  # resource requests and limits for the Ray head container.
  # Modify as needed for your application.
  # Note that the resources in this example are much too small for production;
  # we don't recommend allocating less than 8G memory for a Ray pod in production.
  # Ray pods should be sized to take up entire K8s nodes when possible.
  # Always set CPU and memory limits for Ray pods.
  # It is usually best to set requests equal to limits.
  # See https://docs.ray.io/en/latest/cluster/kubernetes/user-guides/config.html#resources
  # for further guidance.
  resources:
    limits:
      cpu: "{{ RAY_HEAD_CPU_LIMIT }}"
      # To avoid out-of-memory issues, never allocate less than 2G memory for the Ray head.
      memory: "{{ RAY_HEAD_MEMORY_LIMIT }}"
    requests:
      cpu: "{{ RAY_HEAD_CPU_REQUESTS }}"
      memory: "{{ RAY_HEAD_MEMORY_REQUESTS }}"
  annotations: {}
  nodeSelector: {}
  tolerations: []
  affinity: {}
  # Ray container security context.
  securityContext: {}
  ports:
  - containerPort: 6379
    name: gcs
  - containerPort: 8265
    name: dashboard
  - containerPort: 10001
    name: client
  volumes:
    - name: log-volume
      emptyDir: {}
  # Ray writes logs to /tmp/ray/session_latests/logs
  volumeMounts:
    - mountPath: /tmp/ray
      name: log-volume
  # sidecarContainers specifies additional containers to attach to the Ray pod.
  # Follows standard K8s container spec.
  sidecarContainers: []


worker:
  # If you want to disable the default workergroup
  # uncomment the line below
  disabled: true
  groupName: workergroup
  replicas: 1
  labels: {}
  rayStartParams:
    block: 'true'
  initContainerImage: '{{ BUSYBOX_IMG_REPO }}:{{ BUSYBOX_IMG_TAG }}'  # Enable users to specify the image for init container. Users can pull the busybox image from their private repositories.
  # Security context for the init container.
  initContainerSecurityContext: {}
  # containerEnv specifies environment variables for the Ray container,
  # Follows standard K8s container env schema.
  containerEnv:
    - name: RAY_SCHEDULER_SPREAD_THRESHOLD
      value: "0.0"
  envFrom: []
    # - secretRef:
    #     name: my-env-secret
  # ports optionally allows specifying ports for the Ray container.
  # ports: []
  # resource requests and limits for the Ray head container.
  # Modify as needed for your application.
  # Note that the resources in this example are much too small for production;
  # we don't recommend allocating less than 8G memory for a Ray pod in production.
  # Ray pods should be sized to take up entire K8s nodes when possible.
  # Always set CPU and memory limits for Ray pods.
  # It is usually best to set requests equal to limits.
  # See https://docs.ray.io/en/latest/cluster/kubernetes/user-guides/config.html#resources
  # for further guidance.
  resources:
    limits:
      cpu: "8000m"
      memory: "32G"
    requests:
      cpu: "8000m"
      memory: "32G"
  annotations: {}
  nodeSelector: {}
  tolerations: []
  affinity: {}
  # Ray container security context.
  securityContext: {}
  volumes:
    - name: log-volume
      emptyDir: {}
  # Ray writes logs to /tmp/ray/session_latests/logs
  volumeMounts:
    - mountPath: /tmp/ray
      name: log-volume
  # sidecarContainers specifies additional containers to attach to the Ray pod.
  # Follows standard K8s container spec.
  sidecarContainers: []

# The map's key is used as the groupName.
# For example, key:small-group in the map below
# will be used as the groupName
additionalWorkerGroups:
  smallGroup:
    # Disabled by default
    disabled: true
    replicas: 1
    minReplicas: 1
    maxReplicas: 3
    labels: {}
    rayStartParams:
      block: 'true'
    initContainerImage: 'busybox:1.28'  # Enable users to specify the image for init container. Users can pull the busybox image from their private repositories.
    # Security context for the init container.
    initContainerSecurityContext: {}
  # containerEnv specifies environment variables for the Ray container,
  # Follows standard K8s container env schema.
    containerEnv:
    - name: RAY_SCHEDULER_SPREAD_THRESHOLD
      value: "0.0"
    envFrom: []
        # - secretRef:
        #     name: my-env-secret
    # ports optionally allows specifying ports for the Ray container.
    # ports: []
  # resource requests and limits for the Ray head container.
  # Modify as needed for your application.
  # Note that the resources in this example are much too small for production;
  # we don't recommend allocating less than 8G memory for a Ray pod in production.
  # Ray pods should be sized to take up entire K8s nodes when possible.
  # Always set CPU and memory limits for Ray pods.
  # It is usually best to set requests equal to limits.
  # See https://docs.ray.io/en/latest/cluster/kubernetes/user-guides/config.html#resources
  # for further guidance.
    resources:
      limits:
        cpu: 1
        memory: "1G"
      requests:
        cpu: 1
        memory: "1G"
    annotations: {}
    nodeSelector: {}
    tolerations: []
    affinity: {}
    # Ray container security context.
    securityContext: {}
    volumes:
      - name: log-volume
        emptyDir: {}
  # Ray writes logs to /tmp/ray/session_latests/logs
    volumeMounts:
      - mountPath: /tmp/ray
        name: log-volume
    sidecarContainers: []

# Configuration for Head's Kubernetes Service
service:
  # This is optional, and the default is ClusterIP.
  type: ClusterIP
  port: 8080

nameOverride: "kuberay"
fullnameOverride: "kuberay-operator"

storage:
  pvLabelKey: "{{ PV_LABEL_KEY }}"
  storageClassName: "{{ STORAGE_CLASS_NAME }}"
  accessMode: {{ STORAGE_ACCESS_MODE }}
  dataPvLabelKey: ""

serviceAccount:
  # Specifies whether a service account should be created
  create: true
  # The name of the service account to use.
  # If not set and create is true, a name is generated using the fullname template
  name: "kuberay-operator"

# Resources for operator
resources:
  # We usually recommend not to specify default resources and to leave this as a conscious
  # choice for the user. This also increases chances charts run on environments with little
  # resources, such as Minikube. If you do whelm to specify resources, uncomment the following
  # lines, adjust them as necessary, and remove the curly braces after 'resources:'.
  limits:
    cpu: 100m
    # Anecdotally, managing 500 Ray pods requires roughly 500MB memory.
    # Monitor memory usage and adjust as needed.
    memory: 512Mi
  # requests:
  #   cpu: 100m
  #   memory: 512Mi

livenessProbe:
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 5

readinessProbe:
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 5

rbacEnable: true

batchScheduler:
  enabled: false

# Set up `securityContext` to improve Pod security.
# See https://github.com/ray-project/kuberay/blob/master/docs/guidance/pod-security.md for further guidance.
securityContext: {}

nodeSelector: {}

tolerations: []

affinity: {}
