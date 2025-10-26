{{/*
Expand the name of the chart.
*/}}
{{- define "crypto-exchange.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "crypto-exchange.fullname" -}}
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
{{- define "crypto-exchange.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "crypto-exchange.labels" -}}
helm.sh/chart: {{ include "crypto-exchange.chart" . }}
{{ include "crypto-exchange.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "crypto-exchange.selectorLabels" -}}
app.kubernetes.io/name: {{ include "crypto-exchange.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "crypto-exchange.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "crypto-exchange.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
PostgreSQL write service name
*/}}
{{- define "crypto-exchange.postgresql.write.fullname" -}}
{{- printf "%s-postgresql-write" (include "crypto-exchange.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
PostgreSQL read service name
*/}}
{{- define "crypto-exchange.postgresql.read.fullname" -}}
{{- printf "%s-postgresql-read" (include "crypto-exchange.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
