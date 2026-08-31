FROM nginx:stable-alpine-slim

# Remove the default nginx placeholder page
RUN rm -rf /usr/share/nginx/html/*

# Copy the static frontend files into nginx's web root
COPY login.html /usr/share/nginx/html/index.html
COPY login.html home.html cadastro.html /usr/share/nginx/html/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
