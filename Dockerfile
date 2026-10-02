FROM ghcr.io/mhsanaei/3x-ui:v2.9.4

# ابزارهای لازم برای nginx + اسکریپت‌های خودکارسازی
RUN apk add --no-cache nginx gettext bash curl jq coreutils

COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY start.sh /start.sh
COPY bootstrap-inbound.sh /bootstrap-inbound.sh
RUN chmod +x /start.sh /bootstrap-inbound.sh

ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["/start.sh"]
