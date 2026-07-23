# Spring Docker Grafana dashboard template

This directory is not mounted into Grafana. It is a source template for projects
that expose Spring Boot Actuator metrics and Docker logs.

## Required labels

| Label | Example | Description |
| --- | --- | --- |
| project | bosspickseoul | Globally unique project name |
| job | bosspickseoul-service | Prometheus scrape job |
| service_group | service | service or cloud |
| env | dev | dev or prod |
| host | backend-1 | Docker host name |
| service | auth-service | Logical service name |
| application | auth-service | Spring application and discovery name |
| deployment | bosspickseoul-auth-service-dev | Deployed Docker unit |
| container | bosspickseoul-auth-service-dev | Docker container name |
| instance | 192.168.0.13:6081 | Prometheus scrape endpoint |

Prometheus metrics and Loki logs share project, service_group, env, host, and
service. Prometheus additionally uses instance. Loki additionally uses container
and deployment.

## Create a project dashboard

1. Copy a template JSON into grafana/dashboards/<ProjectName>.
2. Replace __PROJECT__ with the project label value.
3. Replace __PROJECT_TITLE__ with the display title.
4. Give every dashboard a globally unique uid.
5. Add Prometheus target files named <project>-<group>-<env>.yml.
6. Restart Grafana or wait for the 30 second provisioning poll.

Do not change spring.application.name only for monitoring. Spring Cloud uses it
as the service discovery identifier. Use container or deployment for the Docker
runtime name.
