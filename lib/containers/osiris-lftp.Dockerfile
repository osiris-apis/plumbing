#
# osiris-lftp - lftp for Osiris
#
# This image provides lftp as required for Osiris. The base image uses Alpine
# Linux and pulls in all required dependencies.
#
# The image uses UID 1000 ("builder") with `/home/builder` as working
# directory.
#
# Arguments:
#
#  * OSRS_FROM="docker.io/library/alpine:latest"
#       This controls the host container used as base for the image.
#

ARG     OSRS_FROM="docker.io/library/alpine:latest"
FROM    "${OSRS_FROM}" AS target

#
# Prepare the target environment. Import required sources from the build
# context.
#

WORKDIR /osiris/build

COPY    tools tools

RUN     apk add --no-cache doas lftp

RUN     adduser --disabled-password --shell /bin/bash --uid 1000 builder
RUN     adduser builder wheel

#
# Clean the build environment up. Drop all build sources that are not required
# in the final artifact.
#

RUN     chown -R "builder:builder" /home/builder
RUN     rm -rf /osiris/build

#
# Rebuild from scratch to drop all intermediate layers and keep the final image
# as small as possible. Then setup the entrypoint.
#

FROM    scratch
COPY    --from=target . .

USER    builder:builder
WORKDIR /home/builder
ENTRYPOINT ["/usr/bin/lftp"]
