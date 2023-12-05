/*
 * Container Build Script
 *
 * This is a `docker buildx` manifest to build all the container images defined
 * in the `./containers/` subdirectory.
 */

/*
 * OSRS_UNIQUEID - Unique Identifier
 *
 * If provided by the caller, this ID must be unique across all builds. It
 * is used to tag immutable images and make them available to external
 * users.
 *
 * If not provided (i.e., an empty string), no such unique tags will be pushed.
 *
 * A common way to generate this ID is to use UUIDs, or to use the current date
 * (e.g., `20210101`).
 *
 * Note that we strongly recommend external users to access images by digest
 * rather than this tag. We mostly use the unique tag to guarantee the image
 * stays available in the registry and is not garbage-collected.
 */

variable "OSRS_UNIQUEID" {
        /*
         * XXX: This should be `null` instead of an empty string, but current
         *      `xbuild+HCL` does not support that.
         */
        default = ""
}

/*
 * Mirroring
 *
 * The custom `mirror()` function takes an image name, an image tag, an
 * optional tag-suffix, as well as an optional unique suffix. It then produces
 * an array of tags for all the configured hosts.
 *
 * If the unique suffix is not empty, an additional tag with the unique suffix
 * is added for each host (replacing the specified suffix). In other words,
 * this function concatenates the configured host with the specified image,
 * tag, "-" and suffix or unique-suffix. The dash is skipped if the suffix is
 * empty.
 */

function "mirror" {
        params = [image, tag, suffix, unique]

        result = flatten([
                for host in [
                        "ghcr.io/osiris-apis",
                ] : concat(
                        notequal(suffix, "") ?
                                ["${host}/${image}:${tag}-${suffix}"] :
                                ["${host}/${image}:${tag}"],
                        notequal(unique, "") ?
                                ["${host}/${image}:${tag}-${unique}"] :
                                [],
                )
        ])
}

/*
 * Target Groups
 *
 * The following section defines some custom target groups, which we use in
 * the CI system to rebuild a given set of images.
 *
 *     all-images
 *         Build all "product" images. That is, all images that are part of
 *         the project release and thus used by external entities.
 */

group "all-images" {
        targets = [
                "all-osiris-android-sdk",
                "all-osiris-ci",
                "all-osiris-lftp",
                "all-osiris-mdbook",
        ]
}

/*
 * Virtual Base Targets
 *
 * This section defines virtual base targets, which are shared across the
 * different dependent targets.
 */

target "virtual-default" {
        context = "."
        labels = {
                "org.opencontainers.image.source" = "https://github.com/osiris-apis/plumbing",
        }
}

target "virtual-platforms" {
        platforms = [
                "linux/amd64",
        ]
}

/*
 * osiris-android-sdk - Android SDK Images for Osiris
 */

group "all-osiris-android-sdk" {
        targets = [
                "osiris-android-sdk-latest",
        ]
}

target "virtual-osiris-android-sdk" {
        args = {
                OSRS_APT_PACKAGES = join(",", [
                        "build-essential",
                        "curl",
                        "jq",
                        "openjdk-17-jdk-headless",
                        "unzip",
                        "xq",
                ]),
        }
        dockerfile = "osiris-android-sdk.Dockerfile"
        inherits = [
                "virtual-default",
                "virtual-platforms",
        ]
}

target "osiris-android-sdk-latest" {
        args = {
                OSRS_FROM = "docker.io/library/ubuntu:rolling",
        }
        inherits = [
                "virtual-osiris-android-sdk",
        ]
        tags = concat(
                mirror("osiris-android-sdk", "latest", "", OSRS_UNIQUEID),
        )
}

/*
 * osiris-ci - Continuous Integration for Osiris
 */

group "all-osiris-ci" {
        targets = [
                "osiris-ci-latest",
        ]
}

target "virtual-osiris-ci" {
        args = {
                OSRS_APT_PACKAGES = join(",", [
                        "bash",
                        "build-essential",
                        "ca-certificates",
                        "curl",
                        "jq",
                        "libgtk-4-dev",
                        "libadwaita-1-dev",
                        "sudo",
                ]),
        }
        dockerfile = "osiris-ci.Dockerfile"
        inherits = [
                "virtual-default",
                "virtual-platforms",
        ]
}

target "osiris-ci-latest" {
        args = {
                OSRS_FROM = "docker.io/library/ubuntu:latest",
        }
        inherits = [
                "virtual-osiris-ci",
        ]
        tags = concat(
                mirror("osiris-ci", "latest", "", OSRS_UNIQUEID),
        )
}

/*
 * osiris-lftp - lftp for Osiris
 */

group "all-osiris-lftp" {
        targets = [
                "osiris-lftp-latest",
        ]
}

target "virtual-osiris-lftp" {
        dockerfile = "osiris-lftp.Dockerfile"
        inherits = [
                "virtual-default",
                "virtual-platforms",
        ]
}

target "osiris-lftp-latest" {
        args = {
                OSRS_FROM = "docker.io/library/alpine:latest",
        }
        inherits = [
                "virtual-osiris-lftp",
        ]
        tags = concat(
                mirror("osiris-lftp", "latest", "", OSRS_UNIQUEID),
        )
}

/*
 * osiris-mdbook - mdBook for Osiris
 */

group "all-osiris-mdbook" {
        targets = [
                "osiris-mdbook-latest",
        ]
}

target "virtual-osiris-mdbook" {
        dockerfile = "osiris-mdbook.Dockerfile"
        inherits = [
                "virtual-default",
                "virtual-platforms",
        ]
}

target "osiris-mdbook-latest" {
        args = {
                OSRS_FROM = "docker.io/library/alpine:latest",
        }
        inherits = [
                "virtual-osiris-mdbook",
        ]
        tags = concat(
                mirror("osiris-mdbook", "latest", "", OSRS_UNIQUEID),
        )
}
