SynthoLicense: "{{ LICENSE_KEY }}"

kuberay-operator:
  image:
    repository: {{ RAY_OPERATOR_IMG_REPO }}
    tag: {{ RAY_OPERATOR_IMG_TAG }}
    pullPolicy: IfNotPresent
  imagePullSecrets:
    - name: {{ IMAGE_PULL_SECRET }}

  nameOverride: "kuberay-operator"
  fullnameOverride: "kuberay-operator"

  serviceAccount:
    # Specifies whether a service account should be created
    create: true
    # The name of the service account to use.
    # If not set and create is true, a name is generated using the fullname template
    name: "kuberay-operator"

  service:
    type: ClusterIP
    port: 8080

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

  logging:
    # Log encoder to use for stdout (one of 'json' or 'console', default is 'json')
    stdoutEncoder: ""
    # Log encoder to use for file logging (one of 'json' or 'console', default is 'json')
    fileEncoder: ""
    # Directory for kuberay-operator log file
    baseDir: ""
    # File name for kuberay-operator log file
    fileName: ""

  livenessProbe:
    initialDelaySeconds: 10
    periodSeconds: 5
    failureThreshold: 5

  readinessProbe:
    initialDelaySeconds: 10
    periodSeconds: 5
    failureThreshold: 5

  # Enable customized Kubernetes scheduler integration. If enabled, Ray workloads will be scheduled
  # by the customized scheduler.
  #  * "enabled" is the legacy option and will be deprecated soon.
  #  * "name" is the standard option, expecting a scheduler name, supported values are
  #    "default", "volcano", and "yunikorn".
  #
  # Examples:
  #  1. Use volcano (deprecated)
  #       batchScheduler:
  #         enabled: true
  #
  #  2. Use volcano
  #       batchScheduler:
  #         name: volcano
  #
  #  3. Use yunikorn
  #       batchScheduler:
  #         name: yunikorn
  #
  batchScheduler:
    # Deprecated. This option will be removed in the future.
    # Note, for backwards compatibility. When it sets to true, it enables volcano scheduler integration.
    enabled: false
    # Set the customized scheduler name, supported values are "volcano" or "yunikorn", do not set
    # "batchScheduler.enabled=true" at the same time as it will override this option.
    name: ""

  featureGates:
    - name: RayClusterStatusConditions
      enabled: false


  # Set up `securityContext` to improve Pod security.
  # See https://github.com/ray-project/kuberay/blob/master/docs/guidance/pod-security.md for further guidance.
  podSecurityContext: {}

  # Set up `securityContext` to improve container security.
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
      - ALL
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault

  # if userKubernetesProxy is set to true, the KubeRay operator will be configured with the --use-kubernetes-proxy flag.
  # Using this option to configure kuberay-operator to comunitcate to Ray head pods by proxying through the Kubernetes API Server.
  # useKubernetesProxy: true

  # If leaderElectionEnabled is set to true, the KubeRay operator will use leader election for high availability.
  leaderElectionEnabled: true

  # If rbacEnable is set to false, no RBAC resources will be created, including the Role for leader election, the Role for Pods and Services, and so on.
  rbacEnable: true

  # When crNamespacedRbacEnable is set to true, the KubeRay operator will create a Role for RayCluster preparation (e.g., Pods, Services)
  # and a corresponding RoleBinding for each namespace listed in the "watchNamespace" parameter. Please note that even if crNamespacedRbacEnable
  # is set to false, the Role and RoleBinding for leader election will still be created.
  #
  # Note:
  # (1) This variable is only effective when rbacEnable and singleNamespaceInstall are both set to true.
  # (2) In most cases, it should be set to true, unless you are using a Kubernetes cluster managed by GitOps tools such as ArgoCD.
  crNamespacedRbacEnable: true

  # When singleNamespaceInstall is true:
  # - Install namespaced RBAC resources such as Role and RoleBinding instead of cluster-scoped ones like ClusterRole and ClusterRoleBinding so that
  #   the chart can be installed by users with permissions restricted to a single namespace.
  #   (Please note that this excludes the CRDs, which can only be installed at the cluster scope.)
  # - If "watchNamespace" is not set, the KubeRay operator will, by default, only listen
  #   to resource events within its own namespace.
  singleNamespaceInstall: true

  # The KubeRay operator will watch the custom resources in the namespaces listed in the "watchNamespace" parameter.
  # watchNamespace:
  #   - n1
  #   - n2

  # Environment variables
  env:
  # If not set or set to true, kuberay auto injects an init container waiting for ray GCS.
  # If false, you will need to inject your own init container to ensure ray GCS is up before the ray workers start.
  # Warning: we highly recommend setting to true and let kuberay handle for you.
  # - name: ENABLE_INIT_CONTAINER_INJECTION
  #   value: "true"
  # If set to true, kuberay creates a normal ClusterIP service for a Ray Head instead of a Headless service. Default to false.
  # - name: ENABLE_RAY_HEAD_CLUSTER_IP_SERVICE
  #   value: "false"
  # If not set or set to "", kuberay will pick up the default k8s cluster domain `cluster.local`
  # Otherwise, kuberay will use your custom domain
  # - name: CLUSTER_DOMAIN
  #   value: ""
  # If not set or set to false, when running on OpenShift with Ingress creation enabled, kuberay will create OpenShift route
  # Otherwise, regardless of the type of cluster with Ingress creation enabled, kuberay will create Ingress
  # - name: USE_INGRESS_ON_OPENSHIFT
  #   value: "true"
  # Unconditionally requeue after the number of seconds specified in the
  # environment variable RAYCLUSTER_DEFAULT_REQUEUE_SECONDS_ENV. If the
  # environment variable is not set, requeue after the default value (300).
  # - name: RAYCLUSTER_DEFAULT_REQUEUE_SECONDS_ENV
  #   value: 300
  # If not set or set to "true", KubeRay will clean up the Redis storage namespace when a GCS FT-enabled RayCluster is deleted.
  # - name: ENABLE_GCS_FT_REDIS_CLEANUP
  #   value: "true"dev-demo-cluster
  # For LLM serving, some users might not have sufficient GPU resources to run two RayClusters simultaneously.
  # Therefore, KubeRay offers ENABLE_ZERO_DOWNTIME as a feature flag for zero-downtime upgrades.
  # - name: ENABLE_ZERO_DOWNTIME
  #   value: "true"
  # This environment variable for the KubeRay operator is used to determine whether to enable
  # the injection of readiness and liveness probes into Ray head and worker containers.
  # Enabling this feature contributes to the robustness of Ray clusters.
  # - name: ENABLE_PROBES_INJECTION
  #   value: "true"
  # If set to true, the RayJob CR itself will be deleted if shutdownAfterJobFinishes is set to true. Note that all resources created by the RayJob CR will be deleted, including the K8s Job. Otherwise, only the RayCluster CR will be deleted. Default is false.
  # - name: DELETE_RAYJOB_CR_AFTER_JOB_FINISHES
  #   value: "false"
ray-cluster:
  image:
    repository: {{ RAY_IMAGE_IMG_REPO }}
    tag: {{ RAY_IMAGE_IMG_TAG }}
    pullPolicy: IfNotPresent

  nameOverride: "ray-cluster"
  fullnameOverride: "ray-cluster"

  imagePullSecrets:
    - name: {{ IMAGE_PULL_SECRET }}

  # common defined values shared between the head and worker
  common:
    # Include Syntho License key here
    containerEnv:
    - name: LICENSE_KEY_SIGNED
      valueFrom:
        secretKeyRef:
          name: ray-secret
          key: license_key
  head:
    # rayVersion determines the autoscaler's image version.
    # It should match the Ray version in the image of the containers.
    # rayVersion: 2.9.0
    # If enableInTreeAutoscaling is true, the autoscaler sidecar will be added to the Ray head pod.
    # Ray autoscaler integration is supported only for Ray versions >= 1.11.0
    # Ray autoscaler integration is Beta with KubeRay >= 0.3.0 and Ray >= 2.0.0.
    # enableInTreeAutoscaling: true
    # autoscalerOptions is an OPTIONAL field specifying configuration overrides for the Ray autoscaler.
    # The example configuration shown below represents the DEFAULT values.
    # autoscalerOptions:
      # upscalingMode: Default
      # idleTimeoutSeconds is the number of seconds to wait before scaling down a worker pod which is not using Ray resources.
      # idleTimeoutSeconds: 60
      # imagePullPolicy optionally overrides the autoscaler container's default image pull policy (IfNotPresent).
      # imagePullPolicy: IfNotPresent
      # Optionally specify the autoscaler container's securityContext.
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
    labels: {}
    # Note: From KubeRay v0.6.0, users need to create the ServiceAccount by themselves if they specify the `serviceAccountName`
    # in the headGroupSpec. See https://github.com/ray-project/kuberay/pull/1128 for more details.
    serviceAccountName: ""
    initContainers:
      - name: init-busybox
        command: ["chmod", "-R", "777", "/tmp/ray-workflows", "/tmp/ray-data"]
        securityContext: {}
        image: busybox:1.28
        volumeMounts:
          - mountPath: /tmp/ray-workflows
            name: ray-workflows
          - mountPath: /tmp/ray-data
            name: ray-data
    restartPolicy: ""
    rayStartParams:
      dashboard-host: '0.0.0.0'
      storage: "/tmp/ray-workflows"
    # containerEnv specifies environment variables for the Ray container,
    # Follows standard K8s container env schema.
    containerEnv: []
    # - name: EXAMPLE_ENV
    #   value: "1"
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
    # Pod security context.
    podSecurityContext: {}
    # Ray container security context.
    securityContext: {}
    # Optional: The following volumes/volumeMounts configurations are optional but recommended because
    # Ray writes logs to /tmp/ray/session_latests/logs instead of stdout/stderr.
    volumes:
      - name: log-volume
        emptyDir: {}
      - name: ray-workflows
        persistentVolumeClaim:
          claimName: ray-workflows-claim
      - name: ray-data
        persistentVolumeClaim:
          claimName: ray-data-claim
    volumeMounts:
      - mountPath: /tmp/ray
        name: log-volume
      - mountPath: /tmp/ray-workflows
        name: ray-workflows
      - mountPath: /tmp/ray-data
        name: ray-data
    # sidecarContainers specifies additional containers to attach to the Ray pod.
    # Follows standard K8s container spec.
    sidecarContainers: []
    # See docs/guidance/pod-command.md for more details about how to specify
    # container command for head Pod.
    command: []
    args: []
    # Optional, for the user to provide any additional fields to the service.
    # See https://pkg.go.dev/k8s.io/Kubernetes/pkg/api/v1#Service
    headService: {}
      # metadata:
      #   annotations:
      #     prometheus.io/scrape: "true"


  worker:
    # If you want to disable the default workergroup
    # uncomment the line below
    disabled: true
    groupName: workergroup
    replicas: 1
    minReplicas: 1
    maxReplicas: 3
    labels: {}
    serviceAccountName: ""
    restartPolicy: ""
    rayStartParams:
      storage: "/tmp/ray-workflows"
    # containerEnv specifies environment variables for the Ray container,
    # Follows standard K8s container env schema.
    containerEnv: []
    # - name: EXAMPLE_ENV
    #   value: "1"
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
        cpu: "1"
        memory: "1G"
      requests:
        cpu: "1"
        memory: "1G"
    annotations: {}
    nodeSelector: {}
    tolerations: []
    affinity: {}
    # Pod security context.
    podSecurityContext: {}
    # Ray container security context.
    securityContext: {}
    # Optional: The following volumes/volumeMounts configurations are optional but recommended because
    # Ray writes logs to /tmp/ray/session_latests/logs instead of stdout/stderr.
    volumes:
      - name: log-volume
        emptyDir: {}
      - name: ray-workflows
        persistentVolumeClaim:
          claimName: ray-workflows-claim
      - name: ray-data
        persistentVolumeClaim:
          claimName: ray-data-claim
    volumeMounts:
      - mountPath: /tmp/ray
        name: log-volume
      - mountPath: /tmp/ray-workflows
        name: ray-workflows
      - mountPath: /tmp/ray-data
        name: ray-data
    # sidecarContainers specifies additional containers to attach to the Ray pod.
    # Follows standard K8s container spec.
    sidecarContainers: []
    # See docs/guidance/pod-command.md for more details about how to specify
    # container command for worker Pod.
    command: []
    args: []

  # The map's key is used as the groupName.
  # For example, key:small-group in the map below
  # will be used as the groupName
  additionalWorkerGroups:
    smallGroup:
      # Disabled by default
      disabled: true
      replicas: 0
      minReplicas: 0
      maxReplicas: 3
      labels: {}
      serviceAccountName: ""
      restartPolicy: ""
      rayStartParams:
        storage: "/tmp/ray-workflows"
      # containerEnv specifies environment variables for the Ray container,
      # Follows standard K8s container env schema.
      containerEnv: []
        # - name: EXAMPLE_ENV
        #   value: "1"
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
      # Pod security context.
      podSecurityContext: {}
      # Ray container security context.
      securityContext: {}
      # Optional: The following volumes/volumeMounts configurations are optional but recommended because
      # Ray writes logs to /tmp/ray/session_latests/logs instead of stdout/stderr.
      volumes:
      - name: log-volume
        emptyDir: {}
      - name: ray-workflows
        persistentVolumeClaim:
          claimName: ray-workflows-claim
      - name: ray-data
        persistentVolumeClaim:
          claimName: ray-data-claim
      volumeMounts:
      - mountPath: /tmp/ray
        name: log-volume
      - mountPath: /tmp/ray-workflows
        name: ray-workflows
      - mountPath: /tmp/ray-data
        name: ray-data
      sidecarContainers: []
      # See docs/guidance/pod-command.md for more details about how to specify
      # container command for worker Pod.
      command: []
      args: []

  # Configuration for Head's Kubernetes Service
  service:
    # This is optional, and the default is ClusterIP.
    type: ClusterIP

storage:
  pvLabelKey: "{{ PV_LABEL_KEY }}"
  storageClassName: "{{ STORAGE_CLASS_NAME }}"
  accessMode: {{ STORAGE_ACCESS_MODE }}
  dataPvLabelKey: ""
