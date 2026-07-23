# Spring Docker Grafana 대시보드 템플릿

이 디렉터리는 Grafana에 마운트되지 않습니다. Spring Boot Actuator 메트릭과 Docker 로그를 노출하는 프로젝트를 위한 원본(source) 템플릿입니다.

## 필수 라벨

| 라벨 | 예시 | 설명 |
| --- | --- | --- |
| project | bosspickseoul | 전역에서 고유한 프로젝트 이름 |
| job | bosspickseoul-service | Prometheus scrape job |
| service_group | service | service 또는 cloud |
| env | dev | dev 또는 prod |
| host | backend-1 | Docker 호스트 이름 |
| service | auth-service | 논리적 서비스 이름 |
| application | auth-service | Spring 애플리케이션 및 서비스 디스커버리 이름 |
| deployment | bosspickseoul-auth-service-dev | 배포된 Docker 단위 |
| container | bosspickseoul-auth-service-dev | Docker 컨테이너 이름 |
| instance | 192.168.0.13:6081 | Prometheus scrape 엔드포인트 |

Prometheus 메트릭과 Loki 로그는 project, service_group, env, host, service를 공유합니다. Prometheus는 추가로 instance를, Loki는 추가로 container와 deployment를 사용합니다.

## 데이터소스 참조

패널과 템플릿 변수는 `${DS_*}` 변수가 아니라 고정 uid로 데이터소스를 참조합니다. 프로비저닝된 uid는 `prometheus`와 `loki`입니다(`grafana/provisioning/datasources` 참고). 이 uid는 바꾸지 않습니다. 바꾸면 모든 대시보드가 깨집니다.

## 프로젝트 대시보드 만들기

1. 템플릿 JSON을 `grafana/dashboards/<ProjectName>`으로 복사합니다.
2. `__PROJECT__`를 프로젝트 라벨 값으로 바꿉니다.
3. `__PROJECT_TITLE__`를 표시할 제목으로 바꿉니다.
4. 모든 대시보드에 전역에서 고유한 uid를 부여합니다.
5. 데이터소스 uid는 `prometheus` / `loki`로 유지합니다.
6. `<project>-<group>-<env>.yml` 형식의 Prometheus target 파일을 추가합니다.
7. Grafana를 재시작하거나 30초 프로비저닝 폴링을 기다립니다.

템플릿은 접이식 row 패널, KPI 요약 row, `env` 전환 변수, 대시보드 드롭다운 링크를 갖춘 classic 스키마(schemaVersion 40)를 사용합니다. 이 구성은 Grafana 12에서 안정적으로 프로비저닝됩니다. 탭 / auto-grid(v2 스키마)는 선택 사항이며 `kubernetesDashboards,dashboardNewLayouts` 피처 토글이 필요합니다.

모니터링만을 위해 spring.application.name을 바꾸지 않습니다. Spring Cloud가 이 값을 서비스 디스커버리 식별자로 사용하기 때문입니다. Docker 런타임 이름은 container 또는 deployment를 사용합니다.
