#!/usr/bin/env sh
# 신규 도메인의 Let's Encrypt 최초 발급 전에 사용할 HTTP-only Nginx conf를 생성합니다.

set -eu

DOMAIN="${1:-}"
MODE="${2:-non-www}"

if [ -z "$DOMAIN" ]; then
  echo "사용법: $0 <domain> [non-www|with-www] [output-name]"
  echo "예시: $0 grafana.8llow8llowme.com non-www grafana"
  echo "예시: $0 example.com with-www example"
  exit 1
fi

OUTPUT_NAME="${3:-$DOMAIN}"

case "$MODE" in
  non-www)
    TEMPLATE="./templates/ssl-bootstrap.conf.template"
    ;;
  with-www)
    TEMPLATE="./templates/ssl-bootstrap-with-www.conf.template"
    ;;
  *)
    echo "지원하지 않는 모드입니다: $MODE"
    echo "사용 가능: non-www, with-www"
    exit 1
    ;;
esac

if [ ! -f "$TEMPLATE" ]; then
  echo "템플릿을 찾을 수 없습니다: $TEMPLATE"
  exit 1
fi

mkdir -p ./conf.d
OUTPUT="./conf.d/${OUTPUT_NAME}.bootstrap.conf"

sed "s/__DOMAIN__/${DOMAIN}/g" "$TEMPLATE" > "$OUTPUT"

echo "SSL bootstrap conf를 생성했습니다: $OUTPUT"
echo ""
echo "다음 순서로 진행하세요:"
echo "  docker exec nginx nginx -t"
echo "  docker exec nginx nginx -s reload"
if [ "$MODE" = "with-www" ]; then
  echo "  cd ../certbot && ./init-cert-with-www.sh ${DOMAIN}"
else
  echo "  cd ../certbot && ./init-cert-non-www.sh ${DOMAIN}"
fi
echo "  발급 후 ${OUTPUT}를 제거하거나 실제 HTTPS conf로 교체"

