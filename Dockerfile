FROM nginx:alpine

# Upgrade packages to fix known vulnerabilities (like CVE-2026-27135)
RUN apk update && apk upgrade --no-cache

# Copy the static site content
COPY site/index.html /usr/share/nginx/html/index.html

# Expose port 80
EXPOSE 80

# Use a non-root user for better security (Checkov will like this)
RUN touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid /var/cache/nginx /var/log/nginx /usr/share/nginx/html

USER nginx

CMD ["nginx", "-g", "daemon off;"]
