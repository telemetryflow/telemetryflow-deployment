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
Namespace helper.
*/}}
{{- define "telemetryflow.namespace" -}}
{{- .Values.global.namespace | default .Release.Namespace }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "telemetryflow.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "telemetryflow.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.global.labels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "telemetryflow.selectorLabels" -}}
app.kubernetes.io/name: {{ include "telemetryflow.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Image helper. Expects a dict with repository, tag, pullPolicy.
*/}}
{{- define "telemetryflow.image" -}}
image: "{{ .repository }}:{{ .tag }}"
imagePullPolicy: {{ .pullPolicy | default "IfNotPresent" }}
{{- end }}

{{/*
ServiceAccount name helper. Expects a dict with serviceAccount, component, context.
*/}}
{{- define "telemetryflow.serviceAccountName" -}}
{{- if .serviceAccount.name }}
{{- .serviceAccount.name }}
{{- else }}
{{- printf "%s-%s" (include "telemetryflow.fullname" .context) .component }}
{{- end }}
{{- end }}

{{/*
Chart helper.
*/}}
{{- define "telemetryflow.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}
