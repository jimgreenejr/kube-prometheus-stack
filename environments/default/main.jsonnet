local kp =
  (import 'kube-prometheus/main.libsonnet') +
  // Uncomment the following imports to enable its patches
  // (import 'kube-prometheus/addons/anti-affinity.libsonnet') +
  // (import 'kube-prometheus/addons/managed-cluster.libsonnet') +
  // (import 'kube-prometheus/addons/node-ports.libsonnet') +
  // (import 'kube-prometheus/addons/static-etcd.libsonnet') +
  (import 'kube-prometheus/addons/custom-metrics.libsonnet') +
  (import 'kube-prometheus/addons/external-metrics.libsonnet') +
  {
    values+:: {
      common+: {
        namespace: 'monitoring',
        versions+:: {
          prometheus: "2.36.2",
          grafana: "9.0.2",
          nodeexporter: "1.3.1",
          alertmanager: "0.24.0",
        },
      },
      prometheus+:: {
         thanos: {
           version: '0.27.0',
           image: 'quay.io/thanos/thanos:v0.27.0',
           objectStorageConfig: {
             key: 'thanos.yaml',
             name: 'thanos-objectstorage',
           },
         },
         namespaces+: ['istio-system'],
         prometheus+: {
           spec+: {
             retention: '3d',

             storage: { 
               volumeClaimTemplate: {
                 apiVersion: 'v1',
                 kind: 'PersistentVolumeClaim',
                 spec: {
                   accessModes: ['ReadWriteOnce'],
                   resources: { requests: { storage: '100Gi' } },
                   storageClassName: 'premium-rwo',
                 },
               },
             },  // storage
           },  // spec
         },  // prometheus
      }, //prometheus
      alertmanager+: {
        config: |||
          global:
            resolve_timeout: 10m
            slack_api_url: 'https://hooks.slack.com/services/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'
          route:
              receiver: 'slack-notifications'
              group_by: [alertname, datacenter, app]
          receivers:
          - name: 'slack-notifications'
            slack_configs:
            - channel: '#alerts-prometheus'
              text: 'https://internal.myorg.net/wiki/alerts/{{ .GroupLabels.app }}/{{ .GroupLabels.alertname }}'
        |||,
      },
      grafana+:: {
        folderDashboards+:: {
          Istio: {
            'istio-control-plane-dashboard.json': (import './dashboards/istio-control-plane-dashboard.json'),
            'istio-mesh-dashboard.json': (import './dashboards/istio-mesh-dashboard.json'),
            'istio-service-dashboard.json': (import './dashboards/istio-service-dashboard.json'),
            'istio-workload-dashboard.json': (import './dashboards/istio-workload-dashboard.json'),
            'istio-wasm-extension-dashboard.json': (import './dashboards/istio-wasm-extension-dashboard.json'),
          },
          OPA: {
            'opa-violations.json': (import './dashboards/opa-violations.json'),
          },
          Memcached: {
            'memcached.json': (import './dashboards/memcached.json'),
          },
          Thanos: {
            'compact.json': (import './dashboards/compact.json'),
            'overview.json': (import './dashboards/overview.json'),
            'query-frontend.json': (import './dashboards/query-frontend.json'),
            'query.json': (import './dashboards/query.json'),
            'sidecar.json': (import './dashboards/sidecar.json'),
            'store.json': (import './dashboards/store.json'),
          },
        },
        datasources+:: [
          {
            name: 'loki',
            type: 'loki',
            access: 'proxy',
            org_id: 1,
            url: 'http://release-loki-distributed-gateway.loki.svc.cluster.local',
            version: 1,
            editable: true,
          },
          {
            name: 'prometheus',
            type: 'prometheus',
            access: 'proxy',
            orgId: 1,
            url: 'http://prometheus-k8s.monitoring.svc:9090',
            version: 1,
            editable: false,
          },
          {
            name: 'thanos',
            type: 'prometheus',
            access: 'proxy',
            orgId: 1,
            url: 'http://thanos-query-frontend.monitoring.svc:9090',
            version: 1,
            editable: false,
          }
        ], 
        config: {
          sections: {
            "auth.anonymous": {enabled: true},
          },
        },  
      },
    },
  };

{ 'setup/0namespace-namespace': kp.kubePrometheus.namespace } +
{
  ['setup/prometheus-operator-' + name]: kp.prometheusOperator[name]
  for name in std.filter((function(name) name != 'serviceMonitor' && name != 'prometheusRule'), std.objectFields(kp.prometheusOperator))
} +
// serviceMonitor and prometheusRule are separated so that they can be created after the CRDs are ready
{ 'prometheus-operator-serviceMonitor': kp.prometheusOperator.serviceMonitor } +
{ 'prometheus-operator-prometheusRule': kp.prometheusOperator.prometheusRule } +
{ 'kube-prometheus-prometheusRule': kp.kubePrometheus.prometheusRule } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['blackbox-exporter-' + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['kubernetes-' + name]: kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) }
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) }
// { ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) }
