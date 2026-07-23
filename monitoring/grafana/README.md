# Grafana dashboards as code

Grafana loads JSON files under dashboards into folders that match the filesystem
structure. For example, dashboards/BossPickSeoul becomes the BossPickSeoul
folder in Grafana.

Provisioned dashboards are read-only in the UI. Make changes in Git and wait up
to 30 seconds, or restart only the Grafana container.

## BossPickSeoul dashboards

- 01-backend-overview.json: service health, throughput, p95, heap, 5xx
- 02-backend-logs.json: Loki log volume, WARN/ERROR, service logs
- 03-jpa-repository.json: Spring Data repository rate, duration, errors
- 04-http-performance.json: URI throughput, percentiles, status codes
- 05-jvm.json: heap, process CPU, threads, GC pauses

The project filter is a hidden constant. All other filters use regex matching so
the Grafana All value can safely expand to .*.
