{{/*
Expand the name of the chart.
*/}}
{{- define "security-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "security-server.fullname" -}}
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
{{- define "security-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "security-server.labels" -}}
helm.sh/chart: {{ include "security-server.chart" . }}
{{ include "security-server.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common selector labels
*/}}
{{- define "security-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "security-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common primary labels
*/}}
{{- define "security-server-primary.labels" -}}
{{ include "security-server.labels" . }}
app.kubernetes.io/component: primary
{{- end }}

{{/*
Common primary selector labels
*/}}
{{- define "security-server-primary.selectorLabels" -}}
{{ include "security-server.selectorLabels" . }}
app.kubernetes.io/component: primary
{{- end }}

{{/*
Common secondary labels
*/}}
{{- define "security-server-secondary.labels" -}}
{{ include "security-server.labels" . }}
app.kubernetes.io/component: secondary
{{- end }}

{{/*
Common secondary selector labels
*/}}
{{- define "security-server-secondary.selectorLabels" -}}
{{ include "security-server.selectorLabels" . }}
app.kubernetes.io/component: secondary
{{- end }}

{{/*
Primary volume labels
*/}}
{{- define "security-server-primary.volumeLabels" -}}
app.kubernetes.io/name: {{ include "security-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: primary
{{- end }}
