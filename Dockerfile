# syntax=docker/dockerfile:1

ARG OWNER ZendaiOwl
ARG REPO nextcloudpi
ARG BRANCH Refactoring

FROM nextcloud:apache-alpine AS base
COPY . .
ENV DOCKERBUILD 1
ARG OWNER ZendaiOwl
ARG REPO nextcloudpi
ARG BRANCH Refactoring
RUN source etc/library.sh; \
    mkdir --parents /usr/local/etc/ncp-config.d/; \
    cp etc/ncp-config.d/nc-nextcloud.cfg /usr/local/etc/ncp-config.d/; \
    cp etc/library.sh /usr/local/etc/; \
    cp etc/ncp.cfg /usr/local/etc/; \
    cp -r etc/ncp-templates /usr/local/etc/; \
    

