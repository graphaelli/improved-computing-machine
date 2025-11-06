#!/bin/bash -e

if [ -z "${OTLP_ENDPOINT}" ]; then
  echo "expected OTLP_ENDPOINT"
  exit 1
fi

if [ -z "${OTLP_API_KEY}" ]; then
  echo "expected OTLP_API_KEY"
  exit 1
fi

cat << EOF
receivers:
  hostmetrics:
    collection_interval: 30s
    scrapers:
      cpu:
        metrics:
          system.cpu.utilization:
            enabled: true
          system.cpu.logical.count:
            enabled: true
      disk:
      filesystem:
      load:
      memory:
        metrics:
          system.memory.utilization:
            enabled: true
      network:
      processes:

processors:
  attributes:
    actions:
      - key: instance
        value: \${env:ITERATION}-\${env:INSTANCE}
        action: insert

  batch:
  resourcedetection:
    detectors: ["system"]
    system:
      hostname_sources: ["os"]
      resource_attributes:
        host.name:
          enabled: true
        host.id:
          enabled: false
        host.arch:
          enabled: true
        host.ip:
          enabled: true
        host.mac:
          enabled: true
        host.cpu.vendor.id:
          enabled: true
        host.cpu.family:
          enabled: true
        host.cpu.model.id:
          enabled: true
        host.cpu.model.name:
          enabled: true
        host.cpu.stepping:
          enabled: true
        host.cpu.cache.l2.size:
          enabled: true
        os.description:
          enabled: true
        os.type:
          enabled: true

exporters:
EOF

if [ -n "${OTLP_ENDPOINT}" ]; then
cat << EOF
  otlp:
    endpoint: ${OTLP_ENDPOINT}
    headers:
      authorization: ApiKey ${OTLP_API_KEY}
EOF
fi

if [ -n "${ELASTICSEARCH_ENDPOINT}" ]; then
cat << EOF
  elasticsearch:
    endpoint: ${ELASTICSEARCH_ENDPOINT}
    api_key: ${ELASTICSEARCH_API_KEY}
EOF
fi

cat << EOF

service:
  pipelines:
EOF

if [ -n "${OTLP_ENDPOINT}" ]; then
cat << EOF
    metrics/otlp:
      receivers: [hostmetrics]
      processors: [attributes,resourcedetection,batch]
      exporters: [otlp]
EOF
fi

if [ -n "${ELASTICSEARCH_ENDPOINT}" ]; then
cat << EOF
    metrics/elasticsearch:
      receivers: [hostmetrics]
      processors: [attributes,resourcedetection]
      exporters: [elasticsearch]
EOF
fi

if [ -z "${MONITORING_OTLP_ENDPOINT}" ] || [ -z "${MONITORING_API_KEY}" ]; then
  cat << EOF
  telemetry:
    logs:
      level: warn
    metrics:
      level: none
EOF
else
  cat << EOF
  telemetry:
    logs:
      level: warn
    metrics:
      readers:
        - periodic:
            exporter:
              otlp:
                protocol: http/protobuf
              endpoint: ${MONITORING_OTLP_ENDPOINT}
              headers:
                authorization: ApiKey ${MONITORING_API_KEY}
EOF
fi