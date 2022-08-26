#!/usr/bin/env bash

set -o errexit  # abort on nonzero exit status
set -o nounset  # abort on unbound variable
set -o pipefail # don't hide errors within pipes

# globals

#
# Start of dynamic data
#

# image registry
REGISTRIES=(
  "docker.io/rpinz"           # docker
  "registry.gitlab.com/rpinz" # gitlab
  "ghcr.io/rpinz"             # github
)

# os vendor
OSVENDORS=(
  "docker.io/library/ubuntu"
)

# os versions
OSVERSIONS=(
  "bionic" # 18.04
  "focal"  # 20.04
  "jammy"  # 22.04
)

# os platforms
OSPLATFORMS=(
  "linux/amd64,"
  "linux/arm64,"
  #"linux/arm/v7,"
  #"linux/arm/v6,"
)

# go versions
GOVERSIONS=(
  #"1.18"
)

#
# End of dynamic data
#

# latest golang version
GOLATEST="$(curl -s https://go.dev/VERSION?m=text)" # get latest version
GOLATEST="${GOLATEST##??}" # remove first 2 characters ("go")
GOVERSIONS+="${GOLATEST:-1.19}" # add latest to versions list

# concatenate and clean platform list
OSPLATFORMS="${OSPLATFORMS[@]}" # concatenate array
OSPLATFORMS="${OSPLATFORMS//[[:space:]]/}" # remove whitespace
OSPLATFORMS="${OSPLATFORMS%?}" # remove last character (trailing comma)

GOLANG="golang"
DOCKER_ARGS=()
GOVERSION=""
OSVENDOR=""
OSVERSION=""
REGISTRY=""
COMMAND=""
NO_CACHE=""

# functions

usage() {
  echo " 🐳 ${0:-build.sh} < create | destroy < local | build | buildx > > [ no-cache ]"
  echo
  echo " create|destroy - create/destroy buildx builder"
  echo "          local - (local) container(s)"
  echo "          build - (build) container(s) and push to registry"
  echo "         buildx - (buildx) multi-arch container(s) and push to registry"
  echo "       no-cache - build without cache"
}

get_command() {
  echo "${1:-local}"
}

get_nocache() {
  if [ "${1:-}" = "no" ]; then
    echo "--no-cache"
  fi
}

get_args() {
  DOCKER_ARGS=(
    --tag "$1"
    --build-arg "OSVENDOR=$OSVENDOR"
    --build-arg "OSVERSION=$OSVERSION"
    --build-arg "GOVERSION=$GOVERSION"
  )
}

docker() {
  (
    $(which docker) $*
  )
}

push() {
  echo " 🐳 Pushing $1"
  docker push "$1"
}

pull() {
  if [ "$COMMAND" != "buildx" -a "$(docker images | grep -e ${OSVENDOR}.*${OSVERSION})" = "" ]; then
    echo " 🐳 Pulling $1"
    docker pull "$1"
  fi
}

build() {
  get_args $*
  echo " 🐳 Building $1 for $OSVENDOR $OSVERSION"
  docker build $NO_CACHE ${DOCKER_ARGS[@]} .
}

buildx_create() {
  echo " 🐳 Creating buildx $1"
  docker buildx create --name "$1" --driver-opt "network=host" --bootstrap
}

buildx_destroy() {
  echo " 🐳 Removing buildx $1"
  docker buildx rm "$1"
}

buildx_use() {
  echo " 🐳 Using buildx $1"
  docker buildx use "$1"
}

buildx_stop() {
  if [ "$COMMAND" = "buildx" ]; then
    echo " 🐳 Stopping buildx $1"
    docker buildx stop "$1"
  fi
}

buildx_pull() {
  if [ "$COMMAND" = "buildx" ]; then
    echo " 🐳 Pulling dockerfile:*"
    pull docker.io/docker/dockerfile:1
    pull docker.io/docker/dockerfile:latest
    pull docker.io/moby/buildkit:buildx-stable-1
  fi
}

buildx_prune() {
  echo " 🐳 Pruning buildx $1"
  docker buildx prune
}

buildx() {
  get_args $*
  if [ "$COMMAND" = "buildx" ]; then
    echo " 🐳 Buildxing $1 for $OSVENDOR $OSVERSION"
    docker buildx build $NO_CACHE --platform "${OSPLATFORMS// }" ${DOCKER_ARGS[@]} --push .
  fi
}

builder() {
  case "$1" in
    "buildx")
      for REGISTRY in ${REGISTRIES[@]}; do
        buildx "${REGISTRY}/${GOLANG}:${GOVERSION}-${OSVERSION}"
      done
    ;;
    "build")
      for REGISTRY in ${REGISTRIES[@]}; do
        build "${REGISTRY}/${GOLANG}:${GOVERSION}-${OSVERSION}" \
          && push "${REGISTRY}/${GOLANG}:${GOVERSION}-${OSVERSION}"
      done
    ;;
    "local")
      build "${GOLANG}:${GOVERSION}-${OSVERSION}"
    ;;
    *)
      usage $*
  esac
}

loop() {
  for OSVENDOR in ${OSVENDORS[@]}; do
    for OSVERSION in ${OSVERSIONS[@]}; do
      pull "${OSVENDOR}:${OSVERSION}"
      for GOVERSION in ${GOVERSIONS[@]}; do
        builder "$COMMAND"
      done
    done
  done
}

main() {
  COMMAND="$(get_command ${1:-usage})"
  NO_CACHE="$(get_nocache ${2:-})"

  case "$COMMAND" in
    "create")
      buildx_create "$GOLANG" || return 0
      buildx_use "$GOLANG"
      buildx_pull
      COMMAND="buildx"
      loop $*
      buildx_stop "$GOLANG"
    ;;
    "destroy")
      buildx_stop "$GOLANG"
      buildx_destroy "$GOLANG" && exit 0 || exit 1
    ;;
    "buildx")
      buildx_use "$GOLANG"
      buildx_pull
      loop $*
      buildx_stop "$GOLANG"
    ;;
    "build"|"local")
      loop $*
    ;;
    "usage")
      usage $*
  esac
}

main $*

# EOF
