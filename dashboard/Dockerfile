FROM php:8.3-apache

LABEL org.opencontainers.image.title="WZI Enterprise Operations Dashboard"
LABEL org.opencontainers.image.version="1.5.0"
LABEL org.opencontainers.image.description="Read-only WZI Core Stack operations dashboard"

ENV APACHE_DOCUMENT_ROOT=/var/www/html

RUN a2enmod headers rewrite

COPY public/ /var/www/html/

RUN chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \;

RUN printf '%s\n' \
    '<Directory /var/www/html>' \
    '    Options -Indexes' \
    '    AllowOverride None' \
    '    Require all granted' \
    '</Directory>' \
    '' \
    'ServerTokens Prod' \
    'ServerSignature Off' \
    > /etc/apache2/conf-available/wzi-dashboard-security.conf \
    && a2enconf wzi-dashboard-security

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl --fail --silent http://127.0.0.1/ >/dev/null || exit 1
