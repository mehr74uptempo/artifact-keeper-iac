{{/*
=============================================================================
EXAMPLE CONFIGURATION - Getting Started Template
=============================================================================
This file is provided as a starting point for deployments. It should be
reviewed and modified to match your specific infrastructure requirements,
security policies, and operational needs before use in production.
=============================================================================
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "artifact-keeper.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "artifact-keeper.fullname" -}}
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
{{- define "artifact-keeper.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "artifact-keeper.labels" -}}
helm.sh/chart: {{ include "artifact-keeper.chart" . }}
{{ include "artifact-keeper.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: artifact-keeper
{{- end }}

{{/*
Selector labels
*/}}
{{- define "artifact-keeper.selectorLabels" -}}
app.kubernetes.io/name: {{ include "artifact-keeper.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Backend selector labels
*/}}
{{- define "artifact-keeper.backend.selectorLabels" -}}
{{ include "artifact-keeper.selectorLabels" . }}
app.kubernetes.io/component: backend
{{- end }}

{{/*
Web selector labels
*/}}
{{- define "artifact-keeper.web.selectorLabels" -}}
{{ include "artifact-keeper.selectorLabels" . }}
app.kubernetes.io/component: web
{{- end }}

{{/*
Edge selector labels
*/}}
{{- define "artifact-keeper.edge.selectorLabels" -}}
{{ include "artifact-keeper.selectorLabels" . }}
app.kubernetes.io/component: edge
{{- end }}

{{/*
PostgreSQL selector labels
*/}}
{{- define "artifact-keeper.postgres.selectorLabels" -}}
{{ include "artifact-keeper.selectorLabels" . }}
app.kubernetes.io/component: postgres
{{- end }}

{{/*
OpenSearch selector labels
*/}}
{{- define "artifact-keeper.opensearch.selectorLabels" -}}
{{ include "artifact-keeper.selectorLabels" . }}
app.kubernetes.io/component: opensearch
{{- end }}

{{/*
OpenSearch initial cluster manager nodes (comma-separated list of pod names)
Used only when replicaCount > 1 to bootstrap a multi-node cluster.
*/}}
{{- define "artifact-keeper.opensearch.initialMasterNodes" -}}
{{- $fullName := include "artifact-keeper.fullname" . -}}
{{- $replicaCount := int .Values.opensearch.replicaCount -}}
{{- $nodes := list -}}
{{- range $i, $_ := until $replicaCount -}}
{{- $nodes = append $nodes (printf "%s-opensearch-%d" $fullName $i) -}}
{{- end -}}
{{- join "," $nodes -}}
{{- end }}

{{/*
Trivy selector labels
*/}}
{{- define "artifact-keeper.trivy.selectorLabels" -}}
{{ include "artifact-keeper.selectorLabels" . }}
app.kubernetes.io/component: trivy
{{- end }}

{{/*
Scanner-adapter selector labels
*/}}
{{- define "artifact-keeper.scannerAdapter.selectorLabels" -}}
{{ include "artifact-keeper.selectorLabels" . }}
app.kubernetes.io/component: scanner-adapter
{{- end }}

{{/*
DependencyTrack selector labels
*/}}
{{- define "artifact-keeper.dtrack.selectorLabels" -}}
{{ include "artifact-keeper.selectorLabels" . }}
app.kubernetes.io/component: dependency-track
{{- end }}

{{/*
Database mode selection. The in-cluster postgres wins when enabled and
ignores every other database setting. With postgres disabled the legacy
externalDatabase remains the default; setting externalDatabase.enabled to
false switches backend and DependencyTrack to their per-service
database.existingSecret references (e.g. CloudNativePG `<cluster>-app`
Secrets). Returns "true" when the per-service references are active.
*/}}
{{- define "artifact-keeper.dedicatedDatabase" -}}
{{- if and (not .Values.postgres.enabled) (hasKey .Values.externalDatabase "enabled") (not .Values.externalDatabase.enabled) -}}
true
{{- end -}}
{{- end }}

{{/*
Per-service database secret key lookups, defaulting to the CloudNativePG
application-secret key names when secretKeys (or an individual key) is unset.
*/}}
{{- define "artifact-keeper.backend.dbSecretKey" -}}
{{- $keys := .root.Values.backend.database.secretKeys | default dict -}}
{{- get $keys .key | default .default -}}
{{- end }}

{{- define "artifact-keeper.dtrack.dbSecretKey" -}}
{{- $keys := .root.Values.dependencyTrack.database.secretKeys | default dict -}}
{{- get $keys .key | default .default -}}
{{- end }}

{{/*
Database URL helper — returns the full DATABASE_URL string
*/}}
{{- define "artifact-keeper.databaseUrl" -}}
{{- if .Values.postgres.enabled -}}
postgresql://{{ .Values.postgres.auth.username }}:{{ .Values.postgres.auth.password }}@{{ include "artifact-keeper.fullname" . }}-postgres:5432/{{ .Values.postgres.auth.database }}
{{- else -}}
postgresql://{{ .Values.externalDatabase.username }}:{{ .Values.externalDatabase.password }}@{{ .Values.externalDatabase.host }}:{{ .Values.externalDatabase.port }}/{{ .Values.externalDatabase.database }}
{{- end -}}
{{- end }}

{{/*
ServiceAccount name
*/}}
{{- define "artifact-keeper.serviceAccountName" -}}
{{- if .Values.backend.serviceAccount.create }}
{{- default (printf "%s-backend" (include "artifact-keeper.fullname" .)) .Values.backend.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.backend.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "artifact-keeper.validateSecrets" -}}
{{- if not .Values.externalSecrets.enabled -}}
{{- if eq .Values.secrets.jwtSecret "" -}}
{{- fail "secrets.jwtSecret is required when externalSecrets is not enabled. Set it with --set secrets.jwtSecret=<value>" -}}
{{- end -}}
{{- if lt (len .Values.secrets.jwtSecret) 32 -}}
{{- fail "secrets.jwtSecret must be at least 32 characters; the backend refuses shorter secrets at startup. Generate one with e.g. `openssl rand -base64 48`" -}}
{{- end -}}
{{- end -}}
{{- if include "artifact-keeper.dedicatedDatabase" . -}}
{{- if not .Values.backend.database.existingSecret -}}
{{- fail "backend.database.existingSecret is required when externalDatabase.enabled is false" -}}
{{- end -}}
{{- if and .Values.dependencyTrack.enabled (not .Values.dependencyTrack.database.existingSecret) -}}
{{- fail "dependencyTrack.database.existingSecret is required when externalDatabase.enabled is false" -}}
{{- end -}}
{{- end -}}
{{- if not .Values.externalSecrets.enabled -}}
{{- if and .Values.postgres.enabled (eq .Values.postgres.auth.password "") -}}
{{- fail "postgres.auth.password is required when postgres is enabled. Set it with --set postgres.auth.password=<value>" -}}
{{- end -}}
{{- if and .Values.opensearch.enabled (not .Values.opensearch.disableSecurityPlugin) (eq .Values.opensearch.auth.password "") -}}
{{- fail "opensearch.auth.password is required when opensearch is enabled and disableSecurityPlugin is false. Set it with --set opensearch.auth.password=<value>" -}}
{{- end -}}
{{- end -}}
{{- end -}}
