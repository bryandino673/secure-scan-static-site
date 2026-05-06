FROM nginx:alpine

# Upgrade packages to fix known vulnerabilities (like CVE-2026-27135)
RUN apk update && apk upgrade --no-cache

# Copy custom nginx configuration (listens on port 8080 for non-root)
COPY site/nginx.conf /etc/nginx/nginx.conf

# Copy the static site content
COPY site/index.html /usr/share/nginx/html/index.html

# Expose port 8080 (non-root user cannot bind to port 80)
EXPOSE 8080

# Use a non-root user for better security (Checkov will like this)
RUN touch /tmp/nginx.pid && \
    chown -R nginx:nginx /tmp/nginx.pid /var/cache/nginx /var/log/nginx /usr/share/nginx/html

USER nginx

CMD ["nginx", "-g", "daemon off;"]
