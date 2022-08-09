#!/bin/bash -eu

#
# Based on https://github.com/RPi-Distro/pi-gen/blob/master/build-docker.sh published under the
# BSD 3-Clause "New" or "Revised" License (https://github.com/RPi-Distro/pi-gen/blob/master/LICENSE)
#
# Adjusted for "live-custom-ubuntu-from-scratch" available at https://github.com/mvallim/live-custom-ubuntu-from-scratch
#

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

BUILD_OPTS="$*"

DOCKER="docker"

BUILD_DATE=`TZ="UTC" date +"%y%m%d-%H%M%S"`

if ! ${DOCKER} ps >/dev/null 2>&1; then
	DOCKER="sudo docker"
fi
if ! ${DOCKER} ps >/dev/null; then
	echo "error connecting to docker:"
	${DOCKER} ps
	exit 1
fi

if [[ -f "${DIR}/scripts/config.sh" ]]; then
    . "${DIR}/scripts/config.sh"
elif [[ -f "${DIR}/scripts/default_config.sh" ]]; then
    . "${DIR}/scripts/default_config.sh"
else
    >&2 echo "Unable to find default config file ${DIR}/scripts/default_config.sh, aborting."
    exit 1
fi

echo "TARGET_UBUNTU_VERSION: ${TARGET_UBUNTU_VERSION}"
echo "TARGET_UBUNTU_MIRROR:  ${TARGET_UBUNTU_MIRROR}"
echo "TARGET_KERNEL_PACKAGE: ${TARGET_KERNEL_PACKAGE}"
echo "TARGET_NAME:           ${TARGET_NAME}"

CONTAINER_NAME=${CONTAINER_NAME:-live-custom-ubuntu-from-scratch_work}
CONTINUE=${CONTINUE:-0}
PRESERVE_CONTAINER=${PRESERVE_CONTAINER:-0}

# Ensure the Git Hash is recorded before entering the docker container
GIT_HASH=${GIT_HASH:-"$(git rev-parse HEAD)"}

CONTAINER_EXISTS=$(${DOCKER} ps -a --filter name="${CONTAINER_NAME}" -q)
CONTAINER_RUNNING=$(${DOCKER} ps --filter name="${CONTAINER_NAME}" -q)
if [ "${CONTAINER_RUNNING}" != "" ]; then
	echo "The build is already running in container ${CONTAINER_NAME}. Aborting."
	exit 1
fi
if [ "${CONTAINER_EXISTS}" != "" ] && [ "${CONTINUE}" != "1" ]; then
	echo "Container ${CONTAINER_NAME} already exists and you did not specify CONTINUE=1. Aborting."
	echo "You can delete the existing container like this:"
	echo "  ${DOCKER} rm -v ${CONTAINER_NAME}"
	exit 1
fi

# Modify original build-options to allow config file to be mounted in the docker container
BUILD_OPTS="$(echo "${BUILD_OPTS:-}" | sed -E 's@\-c\s?([^ ]+)@-c /config@')"

${DOCKER} build --build-arg BASE_IMAGE=ubuntu:${TARGET_UBUNTU_VERSION} -t live-custom-ubuntu-from-scratch "${DIR}"

if [ "${CONTAINER_EXISTS}" != "" ]; then
	trap 'echo "got CTRL+C... please wait 5s" && ${DOCKER} stop -t 5 ${CONTAINER_NAME}_cont' SIGINT SIGTERM
	time ${DOCKER} run --rm --privileged \
		--cap-add=ALL \
		-v /dev:/dev \
		-v /lib/modules:/lib/modules \
		-e "GIT_HASH=${GIT_HASH}" \
		--volumes-from="${CONTAINER_NAME}" --name "${CONTAINER_NAME}_cont" \
		live-custom-ubuntu-from-scratch \
		bash -e -o pipefail -c "cd /live-custom-ubuntu-from-scratch/scripts &&
        ./build.sh - &&
        cd .." &
	wait "$!"
else
	trap 'echo "got CTRL+C... please wait 5s" && ${DOCKER} stop -t 5 ${CONTAINER_NAME}' SIGINT SIGTERM
	time ${DOCKER} run --name "${CONTAINER_NAME}" --privileged \
		--cap-add=ALL \
		-v /dev:/dev \
		-v /lib/modules:/lib/modules \
		-e "GIT_HASH=${GIT_HASH}" \
		live-custom-ubuntu-from-scratch \
		bash -e -o pipefail -c "cd /live-custom-ubuntu-from-scratch/scripts &&
        ./build.sh - &&
        cd .." &
	wait "$!"
fi

echo "Copying iso from docker container"
${DOCKER} cp "${CONTAINER_NAME}":/live-custom-ubuntu-from-scratch/scripts/${TARGET_NAME}.iso ./scripts/${TARGET_NAME}-${TARGET_UBUNTU_VERSION}-${BUILD_DATE}.iso
ls -lah scripts

# cleanup
if [ "${PRESERVE_CONTAINER}" != "1" ]; then
	${DOCKER} rm -v "${CONTAINER_NAME}"
fi

echo "Done! Your image(s) should be in scripts/"
