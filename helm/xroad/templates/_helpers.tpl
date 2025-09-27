{{/*
Expand the name of the chart.
*/}}
{{- define "xroad.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "xroad.fullname" -}}
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
{{- define "xroad.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "xroad.labels" -}}
helm.sh/chart: {{ include "xroad.chart" . }}
{{ include "xroad.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "xroad.selectorLabels" -}}
app.kubernetes.io/name: {{ include "xroad.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Central Server fullname
*/}}
{{- define "xroad.centralServer.fullname" -}}
{{- printf "%s-central-server" (include "xroad.fullname" .) }}
{{- end }}

{{/*
Security Server fullname
*/}}
{{- define "xroad.securityServer.fullname" -}}
{{- printf "%s-security-server" (include "xroad.fullname" .) }}
{{- end }}

{{/*
PostgreSQL fullname
*/}}
{{- define "xroad.postgresql.fullname" -}}
{{- printf "%s-postgresql" (include "xroad.fullname" .) }}
{{- end }}
