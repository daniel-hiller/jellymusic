# Runtime-only image: serves a pre-built web bundle with nginx.
#
# Build the bundle first (the CI release job and local dev both do this with the
# pinned Flutter toolchain), then build the image:
#
#   flutter build web --release
#   docker build -t jellymusic-web .
#
# Building Flutter inside the image was avoided on purpose — there is no
# published `cirruslabs/flutter:3.44.7` base image, and this keeps the container
# on the exact same toolchain as every other build.
FROM nginx:1.31-alpine

COPY build/web /usr/share/nginx/html
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
