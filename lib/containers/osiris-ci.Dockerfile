#
# osiris-ci - Continuous Integration for Osiris
#
# This image provides the CI environment as required for Osiris. The base image
# uses Ubuntu Linux and pulls in all required dependencies.
#
# The image uses UID 1000 ("builder") with `/home/builder` as working
# directory.
#
# Arguments:
#
#  * OSRS_FROM="docker.io/library/ubuntu:latest"
#       This controls the host container used as base for the image.
#
#  * OSRS_APT_PACKAGES=""
#       Specify the packages to install into the container. Separate packages
#       by comma. By default, no package is pulled in.
#

ARG     OSRS_FROM="docker.io/library/ubuntu:latest"
FROM    "${OSRS_FROM}" AS target

#
# Prepare the target environment. Import required sources from the build
# context.
#

WORKDIR /osiris/build

COPY    tools tools

ARG     OSRS_APT_PACKAGES=""
RUN     ./tools/aptget.sh "${OSRS_APT_PACKAGES}"

RUN     useradd -mU -s /bin/bash -G sudo -u 1000 builder

#
# Configure the environment for `builder`.
#

USER    builder:builder

RUN     curl \
                --fail \
                --show-error \
                --silent \
                https://sh.rustup.rs \
        | bash \
                -s \
                -- \
                -y
ENV     PATH="/home/builder/.cargo/bin:${PATH}"
RUN     rustup toolchain install nightly
RUN     rustup toolchain install stable
RUN     rustup component add --toolchain nightly rust-src
RUN     rustup component add --toolchain stable rust-src

USER    root:root

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
ENV     PATH="/home/builder/.cargo/bin:${PATH}"
CMD     ["/bin/bash"]
