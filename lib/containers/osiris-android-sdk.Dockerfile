#
# osiris-android-sdk - Android SDK for Osiris
#
# This image provides the Android SDK as required for Osiris. The base image
# uses Ubuntu Linux and pulls in required development utilities.
#
# The image uses UID 1000 ("ubuntu") with `/home/ubuntu` as working
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
#  * Kotlin: KOTLIN_HOME="~/opt/kotlin"
#       The latest Kotlin release is installed into `KOTLIN_HOME`. This is
#       the full release archive as provided by upstream Kotlin.
#
#  * Kotlin-Compose: "${KOTLIN_HOME}/lib/kotlin-compose.jar"
#       The Kotlin-Compose compiler plugin is installed into the Kotlin
#       distribution ready to be used via
#       `-Xplugin=${KOTLIN_HOME}/lib/kotlin-compose.jar`.
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

ENV     OSRS_OPT="/home/ubuntu/opt"
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
# Fetch the latest Kotlin compiler release and provide it int `KOTLIN_HOME`.
# The latest version can be queried via GitHub-releases.
#

ENV     KOTLIN_HOME="${OSRS_OPT}/kotlin"
RUN \
        curl \
                -L \
                --header "X-GitHub-Api-Version:2022-11-28" \
                "https://api.github.com/repos/JetBrains/kotlin/releases/latest" \
                        | jq -cer ".tag_name | .[1:]" \
                        >"${OSRS_OPT}/kotlin-latest.txt"
RUN \
        mkdir -p "${OSRS_OPT}/kotlin-$(cat "${OSRS_OPT}/kotlin-latest.txt")"
RUN \
        curl \
                -L \
                -o "${OSRS_OPT}/kotlin-latest.zip" \
                "https://github.com/JetBrains/kotlin/releases/download/v$(cat "${OSRS_OPT}/kotlin-latest.txt")/kotlin-compiler-$(cat "${OSRS_OPT}/kotlin-latest.txt").zip"
RUN \
        unzip \
                -d "${OSRS_OPT}/kotlin-$(cat "${OSRS_OPT}/kotlin-latest.txt")" \
                "${OSRS_OPT}/kotlin-latest.zip"
RUN \
        ln \
                -s "kotlin-$(cat "${OSRS_OPT}/kotlin-latest.txt")/kotlinc" \
                "${KOTLIN_HOME}"
RUN \
        rm -rf \
                "${OSRS_OPT}/kotlin-latest.txt" \
                "${OSRS_OPT}/kotlin-latest.zip"

#
# Fetch the latest Jetpack-Compose Kotlin Compiler Plugin from the Android
# release repository. Ideally, we would match the Kotlin version and fetch
# a suitable plugin release. However, fetching the latest version should work
# just as well for now.
#

RUN \
        curl \
                -L \
                "https://dl.google.com/android/maven2/androidx/compose/compiler/compiler-hosted/maven-metadata.xml" \
                        | xq -x "/metadata/versioning/latest" \
                        >"${OSRS_OPT}/kotlin-compose-latest.txt"
RUN \
        curl \
                -L \
                -o "${OSRS_OPT}/kotlin-compose-$(cat "${OSRS_OPT}/kotlin-compose-latest.txt").jar" \
                "https://dl.google.com/android/maven2/androidx/compose/compiler/compiler-hosted/$(cat "${OSRS_OPT}/kotlin-compose-latest.txt")/compiler-hosted-$(cat "${OSRS_OPT}/kotlin-compose-latest.txt").jar"
RUN \
        ln \
                -s "kotlin-compose-$(cat "${OSRS_OPT}/kotlin-compose-latest.txt").jar" \
                "kotlin-compose"
RUN \
        ln \
                -s "${OSRS_OPT}/kotlin-compose" \
                "${KOTLIN_HOME}/lib/kotlin-compose.jar"
RUN \
        rm -rf \
                "${OSRS_OPT}/kotlin-compose-latest.txt"

#
# Clean the build environment up. Drop all build sources that are not required
# in the final artifact.
#

RUN     chown -R "ubuntu:ubuntu" /home/ubuntu
RUN     rm -rf /osiris/build

#
# Rebuild from scratch to drop all intermediate layers and keep the final image
# as small as possible. Then setup the entrypoint.
#

FROM    scratch
COPY    --from=target . .

USER    ubuntu:ubuntu
WORKDIR /home/ubuntu
