{{- define "syntho-core.backend.randHex" -}}
    {{- $result := "" }}
    {{- range $i := until . }}
        {{- $rand_hex_char := mod (randNumeric 4 | atoi) 16 | printf "%x" }}
        {{- $result = print $result $rand_hex_char }}
    {{- end }}
    {{- $result }}
{{- end }}

{{- define "syntho-core.backend.user.get-password" -}}
    {{- if .Values.backend.user.password }}
        {{- .Values.backend.user.password }}
    {{- else }}
        {{- $result := "" }}
        {{- range $i := until 16 }}
            {{- $rand_hex_char := mod (randNumeric 4 | atoi) 16 | printf "%x" }}
            {{- $result = print $result $rand_hex_char }}
        {{- end}}
        {{- $result }}
    {{- end }}
{{- end }}

{{- define "syntho-core.backend.get-secret-key" -}}
    {{- if .Values.backend.secretKey }}
        {{- .Values.backend.secretKey }}
    {{- else }}
        {{- $result := "" }}
        {{- range $i := until 64 }}
            {{- $rand_hex_char := mod (randNumeric 4 | atoi) 16 | printf "%x" }}
            {{- $result = print $result $rand_hex_char }}
        {{- end}}
        {{- $result }}
    {{- end }}
{{- end }}