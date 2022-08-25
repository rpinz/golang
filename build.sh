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
  #"registry.gitlab.com/rpinz" # gitlab
  #"ghcr.io/rpinz"             # github
)

# os vendor
OSVENDORS=(
  "ubuntu"
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

# functions

usage() {
  echo " 🐳 ${0:-build.sh} < local | build | buildx > [ no-cache ]"
  echo
  echo " local|build|buildx - (local) container(s)"
  echo "                    - (build) container(s) and push to registry"
  echo "                    - (buildx) multi-arch container(s) and push to registry"
  echo "           no-cache - build without cache"
}

builder_type() {
  echo "${1:-local}"
}

nocache() {
  if [ "${1:-}" = "no" ]; then
    echo "--no-cache"
  fi
}

args() {
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
  echo " 🐳 Pulling $1"
  if [ "$(docker images | grep -e ${OSVENDOR}.*${OSVERSION})" = "" ]; then
    docker pull "$1"
  fi
}

build() {
  args $*
  echo " 🐳 Building $1 for ${OSVENDOR^} ${OSVERSION^}"
  docker build $NO_CACHE ${DOCKER_ARGS[@]} .
}

buildx_create() {
  if [ "$BUILDER_TYPE" = "buildx" ]; then
    echo " 🐳 Creating buildx $1"
    docker buildx create --name "$1" --driver-opt "network=host" --use --bootstrap
  fi
}

buildx_rm() {
  if [ "$BUILDER_TYPE" = "buildx" ]; then
    echo " 🐳 Removing buildx $1"
    docker buildx rm "$1"
  fi
}

buildx() {
  args $*
  if [ "$BUILDER_TYPE" = "buildx" ]; then
    echo " 🐳 Buildxing $1 for ${OSVENDOR^} ${OSVERSION^}"
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

main() {
  for OSVENDOR in ${OSVENDORS[@]}; do
    for OSVERSION in ${OSVERSIONS[@]}; do
      pull "${OSVENDOR}:${OSVERSION}"
      for GOVERSION in ${GOVERSIONS[@]}; do
        builder "$BUILDER_TYPE"
      done
    done
  done
}

BUILDER_TYPE="$(builder_type ${1:-})"
NO_CACHE="$(nocache ${2:-})"

buildx_create "$GOLANG"
main $*
buildx_rm "$GOLANG"

# EOF
