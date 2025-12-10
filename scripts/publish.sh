#!/usr/bin/env bash

set -eu
set -o pipefail

readonly ROOT_DIR="$(cd "$(dirname "${0}")/.." && pwd)"
readonly BIN_DIR="${ROOT_DIR}/.bin"
readonly BUILD_DIR="${ROOT_DIR}/build"

# shellcheck source=SCRIPTDIR/.util/tools.sh
source "${ROOT_DIR}/scripts/.util/tools.sh"

# shellcheck source=SCRIPTDIR/.util/print.sh
source "${ROOT_DIR}/scripts/.util/print.sh"

function main {
  local image_ref token buildpack_path
  token=""

  while [[ "${#}" != 0 ]]; do
    case "${1}" in
      --image-ref|-i)
        image_ref="${2}"
        shift 2
        ;;

      --buildpack-path|-b)
        buildpack_path="${2}"
        shift 2
        ;;

      --token|-t)
        token="${2}"
        shift 2
        ;;

      --help|-h)
        shift 1
        usage
        exit 0
        ;;

      "")
        # skip if the argument is empty
        shift 1
        ;;

      *)
        util::print::error "unknown argument \"${1}\""
        ;;
    esac
  done

  if [[ -z "${image_ref:-}" ]]; then
    usage
    util::print::error "--image-ref is required"
  fi

  repo::prepare

  tools::install "${token}"

  buildpack::publish "${image_ref}" "${buildpack_path}"
}

function usage() {
  cat <<-USAGE
Publishes the mri buildpack to a registry.

OPTIONS
  -i, --image-ref <ref>               Image reference to publish to (required)
  -b, --buildpack-path <filepath>     Path to the buildpack archive (default: ${BUILD_DIR}/buildpack.tgz)
  -t, --token <token>                 Token used to download assets from GitHub (e.g. pack) (optional)
  -h, --help                          Prints the command usage

USAGE
}

function repo::prepare() {
  util::print::title "Preparing repo..."

  mkdir -p "${BIN_DIR}"

  export PATH="${BIN_DIR}:${PATH}"
}

function tools::install() {
  local token
  token="${1}"

  util::tools::pack::install \
    --directory "${BIN_DIR}" \
    --token "${token}"
}

function buildpack::publish() {
  local image_ref buildpack_path

  image_ref="${1}"
  buildpack_path="${2}"

  util::print::title "Publishing mri buildpack..."

  if [[ -z "${buildpack_path:-}" ]]; then
    util::print::info "Using default archive path: ${BUILD_DIR}/buildpack.tgz"
    buildpack_path="${BUILD_DIR}/buildpack.tgz"
  fi

  if [[ ! -f "${buildpack_path}" ]]; then
    util::print::error "buildpack artifact not found at ${buildpack_path}; run scripts/package.sh first"
  fi

  util::print::info "Extracting archive..."
  tmp_dir=$(mktemp -d -p $ROOT_DIR)
  tar -xvf $buildpack_path -C $tmp_dir

  util::print::info "Publishing buildpack to ${image_ref}"

  pack \
    buildpack package $image_ref \
    --path $tmp_dir \
    --format image \
    --publish

  rm -rf $tmp_dir
}

main "${@:-}"

