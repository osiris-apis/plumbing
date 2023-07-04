#
# osiris-android-sdk - Android SDK for Osiris
#
# This image provides the Android SDK as required for Osiris. The base image
# uses Ubuntu Linux and pulls in required development utilities.
#
# The image uses UID 1000 ("builder") with `/home/builder` as working
# directory. The following tools are provided in `~/opt/`:
#
#  * Android SDK: ANDROID_HOME="~/opt/android-sdk"
#       The latest Android SDK is included at the specified position. The
#       `ANDROID_HOME` environment variable provides the location to it.
#       Note that not all sdk features are pulled in by default, but the
#       Android `sdkmanager` can be used to install further parts of the
#       SDK.
#
#  * Gradle: GRADLE_HOME="~/opt/gradle"
#       The latest Gradle release is installed into `GRADLE_HOME`. This is
#       the full release archive as provided by upstream Gradle.
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

ENV     OSRS_OPT="/home/builder/opt"
RUN     mkdir -p "${OSRS_OPT}"

#
# Bootstrap the Android commandlinetools via a fixed version, but then install
# the latest version via a self update. Make sure to accept the SDK licenses.
#

ENV     ANDROID_HOME="${OSRS_OPT}/android-sdk"
RUN     mkdir -p "${ANDROID_HOME}/cmdline-tools"

ENV     OSRS_ANDROID_CLT_FIXED="9477386_latest"
RUN \
        curl \
                -o "commandlinetools-linux.zip" \
                "https://dl.google.com/android/repository/commandlinetools-linux-${OSRS_ANDROID_CLT_FIXED}.zip"
RUN \
        unzip \
                "commandlinetools-linux.zip" \
                -d "cmdline-tools-fixed"
RUN \
        mv \
                "cmdline-tools-fixed/cmdline-tools" \
                "${ANDROID_HOME}/cmdline-tools/fixed"
RUN \
        yes | \
                "${ANDROID_HOME}/cmdline-tools/fixed/bin/sdkmanager" \
                        --licenses
RUN \
        "${ANDROID_HOME}/cmdline-tools/fixed/bin/sdkmanager" \
                --verbose \
                        "cmdline-tools;latest"
RUN \
        rm -rf \
                "commandlinetools-linux.zip" \
                "cmdline-tools-fixed" \
                "${ANDROID_HOME}/cmdline-tools/fixed"
RUN \
        yes | \
                "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" \
                        --licenses

#
# Use the latest Android SDK to pull in all required SDK components. This
# installs:
#
#  * build-tools: Build utilities required for any SDK artifact assembly.
#                 This includes linkers, compression utilities, etc.
#
#  * emulator: The Android emulator is pulled in by the platform, so lets
#              make this explicit and provide it unconditionally.
#
#  * ndk: The native-development kit contains cmake / GNU-make integration,
#         linkers, headers, and system libraries for native code.
#
#  * platforms: The Android platform files of a specific Android version
#               with all the pre-built java utlities and annotations. This
#               is required to build standard Android applications for a
#               given platform.
#
#  * platform-tools: This provides `adb` and other debugging tools.
#

RUN \
        "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" \
                --verbose \
                        "build-tools;34.0.0" \
                        "emulator" \
                        "ndk;25.2.9519653" \
                        "platforms;android-33" \
                        "platform-tools"

#
# Fetch the latest Gradle binary release and provide it in `GRADLE_HOME`. The
# latest version can be queried via `services.gradle.org/versions`, and the
# release archives are available on `services.gradle.org/distributions`.
#

ENV     GRADLE_HOME="${OSRS_OPT}/gradle"
RUN \
        curl "https://services.gradle.org/versions/current" \
                | jq -cer ".version" >"${OSRS_OPT}/gradle-latest.txt"
RUN \
        curl \
                -L \
                -o "${OSRS_OPT}/gradle-latest.zip" \
                "https://services.gradle.org/distributions/gradle-$(cat "${OSRS_OPT}/gradle-latest.txt")-bin.zip"
RUN \
        unzip \
                -d "${OSRS_OPT}" \
                "${OSRS_OPT}/gradle-latest.zip"
RUN \
        ln \
                -s "gradle-$(cat "${OSRS_OPT}/gradle-latest.txt")" \
                "${GRADLE_HOME}"
RUN \
        rm -rf \
                "${OSRS_OPT}/gradle-latest.txt" \
                "${OSRS_OPT}/gradle-latest.zip"

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
