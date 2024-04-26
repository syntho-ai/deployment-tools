# Default values for syntho-core.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

frontend_path:
frontend_url: {{ DOMAIN }}
frontend_protocol: {{ PROTOCOL }}

SynthoLicense: "{{ LICENSE_KEY }}"

core:
  replicaCount: 1
  image:
    repository: {{ SYNTHO_UI_CORE_IMG_REPO }}
    tag: {{ SYNTHO_UI_CORE_IMG_TAG }}
  name: core
  service:
    port: 8080
    type: ClusterIP
  volumes: []
  volumeMounts: []
  database_enabled: true
  celery_args: ['-A', 'app.celery', 'worker', '--loglevel=info', '--concurrency=1', '--max-memory-per-child=50000']
  db:
    username: postgres
    password: postgres
    name: rwdb
    host: postgres
    port: 5432
  port: 8080
  secret_key: ZzXj2az_fnnM59mviJc0hmU_jhcdIVaI51dbEkuiXLk=
  redis:
    host: redis-svc
    port: 6379
    db: 1
  ray_address: ray-cluster-head-svc.syntho.svc.cluster.local
  workers: 1

backend:
  replicaCount: 1
  image:
    repository: {{ SYNTHO_UI_BACKEND_IMG_REPO }}
    tag: {{ SYNTHO_UI_BACKEND_IMG_TAG }}
  name: backend
  port: 8000
  workers: 1
  secret_key: ix!57KPgpcyu!&2mMn69pB#R8zLhxLXAexnNoF!XZvqHB9G4JG%QLmFnE8Rx^3bMF#EG7rAxnWK*7LzKWF8S62qbTC
  redis:
    host: redis-svc
    port: 6379
    db: 0
  service:
    port: 8000
  database_enabled: true
  db:
    user: syntho
    password: syntho-local-password
    name: syntho-backend
    host: database
    port: 5432
  user:
    username: admin
    password: {{ UI_LOGIN_PASSWORD }}
    email: {{ UI_LOGIN_EMAIL }}
  volumes: []
  volumeMounts: []


frontend:
  replicaCount: 1
  name: frontend
  image:
    repository: {{ SYNTHO_UI_FRONTEND_IMG_REPO }}
    tag: {{ SYNTHO_UI_FRONTEND_IMG_TAG }}
  port: 3000
  service:
    port: 3000
  ingress:
    enabled: true
    name: frontend-ingress
    className: {{ INGRESS_CONTROLLER }}
    annotations: {
      nginx.ingress.kubernetes.io/session-cookie-path: "/",
      nginx.ingress.kubernetes.io/use-regex: "true",
      nginx.ingress.kubernetes.io/proxy-buffer-size: "32k",
      nginx.ingress.kubernetes.io/affinity: "cookie",
      nginx.ingress.kubernetes.io/proxy-connect-timeout: "600",
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600",
      nginx.ingress.kubernetes.io/proxy-send-timeout: "600",
      nginx.ingress.kubernetes.io/proxy-body-size: "512m",
    }
    hosts:
      - host: {{ DOMAIN }}
        paths:
          - path: /
            pathType: Prefix

    tls:
      conf:
        - hosts:
          - {{ DOMAIN }}
          secretName: frontend-tls
      enabled: {{ TLS_ENABLED }}

db:
  image:
    repository: {{ POSTGRES_IMG_REPO }}
    tag: {{ POSTGRES_IMG_TAG }}
  storageClassName: "{{ STORAGE_CLASS_NAME }}"
  pvLabelKey: "{{ PV_LABEL_KEY }}"

redis:
  replicaCount: 1
  image:
    repository: {{ REDIS_IMG_REPO }}
    tag: {{ REDIS_IMG_TAG }}
  storageClassName: "{{ STORAGE_CLASS_NAME }}"
  pvLabelKey: "{{ PV_LABEL_KEY }}"

imagePullSecrets:
  - name: {{ IMAGE_PULL_SECRET }}
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  # Specifies whether a service account should be created
  create: true
  # Annotations to add to the service account
  annotations: {}
  # The name of the service account to use.
  # If not set and create is true, a name is generated using the fullname template
  name: ""

podAnnotations: {}

podSecurityContext: {}
  # fsGroup: 2000

securityContext: {}
  # capabilities:
  #   drop:
  #   - ALL
  # readOnlyRootFilesystem: true
  # runAsNonRoot: true
  # runAsUser: 1000

resources: {}
  # We usually recommend not to specify default resources and to leave this as a conscious
  # choice for the user. This also increases chances charts run on environments with little
  # resources, such as Minikube. If you do want to specify resources, uncomment the following
  # lines, adjust them as necessary, and remove the curly braces after 'resources:'.
  # limits:
  #   cpu: 100m
  #   memory: 128Mi
  # requests:
  #   cpu: 100m
  #   memory: 128Mi

## Node labels for pod assignment
## ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#nodeselector
nodeSelector: {}

# Tolerations for nodes that have taints on them.
# Useful if you want to dedicate nodes to just run kafka-exporter
# https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/
tolerations: []

# tolerations:
# - key: "key"
#   operator: "Equal"
#   value: "value"
#   effect: "NoSchedule"

## Pod scheduling preferences (by default keep pods within a release on separate nodes).
## ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity
## By default we don't set affinity
affinity: {}

# affinity:
#  podAffinity:
#    preferredDuringSchedulingIgnoredDuringExecution:
#     - weight: 50
#       podAffinityTerm:
#         labelSelector:
#           matchExpressions:
#           - key: app
#             operator: In
#             values:
#               - syntho
#         topologyKey: "kubernetes.io/hostname"
