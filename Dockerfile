ARG FOUNDRY_PASSWORD
ARG FOUNDRY_RELEASE_URL
ARG FOUNDRY_USERNAME
ARG FOUNDRY_VERSION=10.288
ARG NODE_IMAGE_VERSION=16-alpine3.15
ARG VERSION

FROM node:${NODE_IMAGE_VERSION} as compile-typescript-stage

WORKDIR /root

COPY \
  package.json \
  package-lock.json \
  tsconfig.json \
  ./
RUN npm install && npm install --global typescript
COPY /src/*.ts src/
RUN tsc
RUN grep -l "#!" dist/*.js | xargs chmod a+x

FROM node:${NODE_IMAGE_VERSION} as optional-release-stage

ARG FOUNDRY_PASSWORD
ARG FOUNDRY_RELEASE_URL
ARG FOUNDRY_USERNAME
ARG FOUNDRY_VERSION
ENV ARCHIVE="foundryvtt-${FOUNDRY_VERSION}.zip"

WORKDIR /root
COPY --from=compile-typescript-stage \
  /root/package.json \
  /root/package-lock.json \
  /root/dist/authenticate.js \
  /root/dist/get_release_url.js \
  /root/dist/logging.js \
  ./
# .placeholder file to mitigate https://github.com/moby/moby/issues/37965
RUN mkdir dist && touch dist/.placeholder
RUN \
  if [ -n "${FOUNDRY_USERNAME}" ] && [ -n "${FOUNDRY_PASSWORD}" ]; then \
  npm install && \
  ./authenticate.js "${FOUNDRY_USERNAME}" "${FOUNDRY_PASSWORD}" cookiejar.json && \
  s3_url=$(./get_release_url.js --retry 5 cookiejar.json "${FOUNDRY_VERSION}") && \
  wget -O ${ARCHIVE} "${s3_url}" && \
  unzip -d dist ${ARCHIVE} 'resources/*'; \
  elif [ -n "${FOUNDRY_RELEASE_URL}" ]; then \
  wget -O ${ARCHIVE} "${FOUNDRY_RELEASE_URL}" && \
  unzip -d dist ${ARCHIVE} 'resources/*'; \
  fi

FROM node:${NODE_IMAGE_VERSION} as final-stage

ARG FOUNDRY_UID=1001
ARG FOUNDRY_VERSION
ARG TARGETPLATFORM
ARG VERSION

LABEL com.foundryvtt.version=${FOUNDRY_VERSION}
LABEL org.opencontainers.image.authors="tech@paladins-inn.de"
LABEL org.opencontainers.image.vendor="Paladins Inn"

ENV FOUNDRY_HOME="/home/foundry"
ENV FOUNDRY_VERSION=${FOUNDRY_VERSION}

WORKDIR ${FOUNDRY_HOME}

COPY --from=optional-release-stage /root/dist/ .
COPY --from=compile-typescript-stage /root/dist/ .
COPY \
  package.json \
  package-lock.json \
  src/check_health.sh \
  src/entrypoint.sh \
  src/launcher.sh \
  src/logging.sh \
  ./
RUN apk --update --no-cache add \
  curl \
  jq \
  sed \
  su-exec \
  tzdata \
  && npm install && echo ${VERSION} > image_version.txt \
  && addgroup --system --gid ${FOUNDRY_UID} foundry \
  && adduser --system --uid ${FOUNDRY_UID} --ingroup foundry foundry \
  && chown foundry:foundry -R . 

VOLUME ["/data"]
# HTTP Server
EXPOSE 30000/TCP
# TURN Server
EXPOSE 33478/UDP
EXPOSE 49152-65535/UDP

USER 1001

ENTRYPOINT ["./entrypoint.sh"]
CMD ["resources/app/main.mjs", "--port=30000", "--headless", "--noupdate",\
  "--dataPath=/data"]
