{{/*
Expand the name of the chart.
*/}}
{{- define "syntho-core.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "syntho-core.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "syntho-core.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "syntho-core.labels" -}}
helm.sh/chart: {{ include "syntho-core.chart" . }}
{{ include "syntho-core.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "syntho-core.selectorLabels" -}}
app.kubernetes.io/name: {{ include "syntho-core.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "syntho-core.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "syntho-core.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Databricks workload identity federation: a projected ServiceAccount token that core-api exchanges for short-lived
Databricks OAuth tokens.
*/}}
{{- define "syntho-core.databricksTokenDir" -}}
/var/run/secrets/syntho/databricks
{{- end }}

{{- define "syntho-core.databricksEnv" -}}
{{- with .Values.databricks.workloadIdentity }}
{{- if .enabled }}
- name: DATABRICKS_OIDC_TOKEN_FILE
  value: {{ include "syntho-core.databricksTokenDir" $ }}/token
{{- if .clientId }}
- name: DATABRICKS_CLIENT_ID
  value: {{ .clientId | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{- define "syntho-core.databricksVolumes" -}}
{{- with .Values.databricks.workloadIdentity }}
{{- if .enabled }}
- name: databricks-token
  projected:
    sources:
      - serviceAccountToken:
          path: token
          audience: {{ required "databricks.workloadIdentity.audience is required when Databricks workload identity is enabled" .audience | quote }}
          expirationSeconds: {{ .expirationSeconds | default 3600 }}
{{- end }}
{{- end }}
{{- end }}

{{- define "syntho-core.databricksVolumeMounts" -}}
{{- if .Values.databricks.workloadIdentity.enabled }}
- name: databricks-token
  mountPath: {{ include "syntho-core.databricksTokenDir" . }}
  readOnly: true
{{- end }}
{{- end }}

{{/*
Volumes and volume mounts of the core-api containers: the user-provided ones plus the Databricks token.
*/}}
{{- define "syntho-core.coreVolumes" -}}
{{- $volumes := .Values.core.volumes | default list -}}
{{- if .Values.databricks.workloadIdentity.enabled -}}
{{- $volumes = concat $volumes (include "syntho-core.databricksVolumes" . | fromYamlArray) -}}
{{- end -}}
{{- toYaml $volumes }}
{{- end }}

{{- define "syntho-core.coreVolumeMounts" -}}
{{- $mounts := .Values.core.volumeMounts | default list -}}
{{- if .Values.databricks.workloadIdentity.enabled -}}
{{- $mounts = concat $mounts (include "syntho-core.databricksVolumeMounts" . | fromYamlArray) -}}
{{- end -}}
{{- toYaml $mounts }}
{{- end }}
