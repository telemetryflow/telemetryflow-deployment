{{/*
TelemetryFlow Helm Chart Helpers
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "telemetryflow.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "telemetryflow.fullname" -}}
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
Chart label
*/}}
{{- define "telemetryflow.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "telemetryflow.labels" -}}
helm.sh/chart: {{ include "telemetryflow.chart" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: telemetryflow
{{- with .Values.global.labels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Component labels
*/}}
{{- define "telemetryflow.componentLabels" -}}
{{ include "telemetryflow.labels" . }}
app.kubernetes.io/name: {{ .componentName }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: {{ .componentName }}
{{- end }}

{{/*
Selector labels for a component
*/}}
{{- define "telemetryflow.selectorLabels" -}}
app.kubernetes.io/name: {{ .componentName }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Namespace
*/}}
{{- define "telemetryflow.namespace" -}}
{{- default .Release.Namespace .Values.global.namespace }}
{{- end }}

{{/*
Image pull secrets — merges:
  - enabled entries from values.imagePullSecrets (created by the chart)
  - global.imagePullSecrets (pre-existing secrets, e.g. ESO-managed)
*/}}
{{- define "telemetryflow.imagePullSecrets" -}}
{{- $names := list }}
{{- range $key, $cfg := .Values.imagePullSecrets }}
{{- if and $cfg.enabled $cfg.name }}
{{- $names = append $names $cfg.name }}
{{- end }}
{{- end }}
{{- range .Values.global.imagePullSecrets }}
{{- $names = append $names . }}
{{- end }}
{{- if $names }}
imagePullSecrets:
{{- range uniq $names }}
  - name: {{ . }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Pod-level security context from a component values map.
Usage: {{ include "telemetryflow.podSecurityContext" .Values.tfoBackend }}
*/}}
{{- define "telemetryflow.podSecurityContext" -}}
{{- with .podSecurityContext }}
securityContext:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Container-level security context from a component values map.
Usage: {{ include "telemetryflow.containerSecurityContext" .Values.tfoBackend }}
*/}}
{{- define "telemetryflow.containerSecurityContext" -}}
{{- with .containerSecurityContext }}
securityContext:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Standard node selector + affinity for worker-only scheduling.
Passes the component's nodeSelector and affinity from values.
Usage: {{ include "telemetryflow.nodeSelector" .Values.tfoBackend }}
*/}}
{{- define "telemetryflow.nodeSelector" -}}
{{- with .nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Tolerations helper.
Usage: {{ include "telemetryflow.tolerations" .Values.tfoAgent }}
*/}}
{{- define "telemetryflow.tolerations" -}}
{{- with .tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Affinity helper.
Usage: {{ include "telemetryflow.affinity" .Values.tfoBackend }}
*/}}
{{- define "telemetryflow.affinity" -}}
{{- with .affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
