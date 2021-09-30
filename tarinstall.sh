#!/usr/bin/env sh

# Destination directory for the installation of the final binary.
TARINSTALL_DESTDIR=${TARINSTALL_DESTDIR:-"/usr/local/bin"}

# Path relative the extracted tar where to find the binary to install. When
# empty, this will be the same as the name of the tar file, without any
# extension (so .tar.gz, or .tgz removed).
TARINSTALL_EXTRACT=${TARINSTALL_EXTRACT:-""}

# Name of the binary to place under $TARINSTALL_DESTDIR. When empty, the
# default, this will be basename of the extraction path specified at
# $TARINSTALL_EXTRACT.
TARINSTALL_BIN=${TARINSTALL_BIN:-""}

# Period to keep destination binary in cache without even triggering a download
# attempt. Default to 0, always download. This can be a human-readable period
# such as 3d (3 days), etc.
TARINSTALL_KEEP=${TARINSTALL_KEEP:-0}

# Path to a directory where the content of the tar file will be unpacked and
# **KEPT** after installation. When this isn't an empty string, the binary will
# be linked from the destination directory into this package directory. This is
# useful for installing binaries that cannot run without a number of sibling
# files, e.g. configuration, dynamic libraries, etc.
TARINSTALL_PACKAGE=${TARINSTALL_PACKAGE:-}

# Set this to 1 for increased verbosity
TARINSTALL_VERBOSE=${TARINSTALL_VERBOSE:-0}

verbose() {
  [ "$TARINSTALL_VERBOSE" = "1" ] && printf %s\\n "$1" >&2
}

doexit() {
  if [ -z "${TMPD:-}" ] && [ -d "$TMPD" ]; then
    verbose "Cleaning $TMPD"
    rm -rf "$TMPD"
  fi

  printf %s\\n "$1" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    -d | --dest | --destination)
      TARINSTALL_DESTDIR=$2; shift 2;;
    --dest=* | --destination=*)
      TARINSTALL_DESTDIR="${1#*=}"; shift 1;;

    -b | --bin | --binary)
      TARINSTALL_BIN=$2; shift 2;;
    --bin=* | --binary=*)
      TARINSTALL_BIN="${1#*=}"; shift 1;;

    -x | --extract)
      TARINSTALL_EXTRACT=$2; shift 2;;
    --extract=*)
      TARINSTALL_EXTRACT="${1#*=}"; shift 1;;

    -p | --package)
      TARINSTALL_PACKAGE=$2; shift 2;;
    --package=*)
      TARINSTALL_PACKAGE="${1#*=}"; shift 1;;

    -k | --keep)
      TARINSTALL_KEEP=$2; shift 2;;
    --keep=*)
      TARINSTALL_KEEP="${1#*=}"; shift 1;;

    -v | --verbose)
      TARINSTALL_VERBOSE=1; shift;;

    --)
      shift; break;;
    -*)
      doexit "Unknown option: $1 !";;
    *)
      break;;
  esac
done

download() {
  verbose "Downloading $1"
  if command -v curl >&2 >/dev/null; then
    curl -sSL "$1" > "$2"
  elif command -v wget >&2 >/dev/null; then
    wget -q -O - "$1" > "$2"
  else
    doexit "Can neither find curl, nor wget for downloading"
    return 1
  fi
}

# Return the approx. number of seconds for the human-readable period passed as a
# parameter
howlong() {
  # shellcheck disable=SC3043 # local is implemented in most shells
  local len || true
  if printf %s\\n "$1"|grep -Eqo '^[0-9]+[[:space:]]*[yY]'; then
    len=$(printf %s\\n "$1"  | sed -En 's/([0-9]+)[[:space:]]*[yY].*/\1/p')
    # shellcheck disable=SC2003
    expr "$len" \* 31536000
  elif printf %s\\n "$1"|grep -Eqo '^[0-9]+[[:space:]]*[Mm][Oo]'; then
    len=$(printf %s\\n "$1"  | sed -En 's/([0-9]+)[[:space:]]*[Mm][Oo].*/\1/p')
    # shellcheck disable=SC2003
    expr "$len" \* 2592000
  elif printf %s\\n "$1"|grep -Eqo '^[0-9]+[[:space:]]*[Mm][Ii]'; then
    len=$(printf %s\\n "$1"  | sed -En 's/([0-9]+)[[:space:]]*[Mm][Ii].*/\1/p')
    # shellcheck disable=SC2003
    expr "$len" \* 60
  elif printf %s\\n "$1"|grep -Eqo '^[0-9]+[[:space:]]*m'; then
    len=$(printf %s\\n "$1"  | sed -En 's/([0-9]+)[[:space:]]*m.*/\1/p')
    # shellcheck disable=SC2003
    expr "$len" \* 2592000
  elif printf %s\\n "$1"|grep -Eqo '^[0-9]+[[:space:]]*[Ww]'; then
    len=$(printf %s\\n "$1"  | sed -En 's/([0-9]+)[[:space:]]*[Ww].*/\1/p')
    # shellcheck disable=SC2003
    expr "$len" \* 604800
  elif printf %s\\n "$1"|grep -Eqo '^[0-9]+[[:space:]]*[Dd]'; then
    len=$(printf %s\\n "$1"  | sed -En 's/([0-9]+)[[:space:]]*[Dd].*/\1/p')
    # shellcheck disable=SC2003
    expr "$len" \* 86400
  elif printf %s\\n "$1"|grep -Eqo '^[0-9]+[[:space:]]*[Hh]'; then
    len=$(printf %s\\n "$1"  | sed -En 's/([0-9]+)[[:space:]]*[Hh].*/\1/p')
    # shellcheck disable=SC2003
    expr "$len" \* 3600
  elif printf %s\\n "$1"|grep -Eqo '^[0-9]+[[:space:]]*M'; then
    len=$(printf %s\\n "$1"  | sed -En 's/([0-9]+)[[:space:]]*M.*/\1/p')
    # shellcheck disable=SC2003
    expr "$len" \* 60
  elif printf %s\\n "$1"|grep -Eqo '^[0-9]+[[:space:]]*[Ss]'; then
    len=$(printf %s\\n "$1"  | sed -En 's/([0-9]+)[[:space:]]*[Ss].*/\1/p')
    echo "$len"
  elif printf %s\\n "$1"|grep -Eqo '^[0-9]+'; then
    printf %s\\n "$1"
  fi
}

tarinstall() {
  TMPD=$(mktemp -d)
  download "$1" "${TMPD}/${TARNAME}"
  if ! [ -f "${TMPD}/${TARNAME}" ]; then
    doexit "Could not download from $1 to ${TMPD}/${TARNAME}"
  fi

  # Extract tar file, respect verbosity, but sending all tar output to stderr in
  # order to not pollute stdout (used for the result of this program, which is
  # the path to the installed binary)
  taropts="xf"
  [ "$TARINSTALL_VERBOSE" = "1" ] && taropts="xvf"
  if [ -z "$TARINSTALL_PACKAGE" ]; then
    _dstdir=${TMPD}
  else
    _dstdir=${TARINSTALL_PACKAGE%%*/}
  fi
  mkdir -p "$_dstdir"
  tar -C "$_dstdir" -${taropts} "${TMPD}/${TARNAME}" 1>&2
  rm -f "${TMPD}/${TARNAME}"

  # If we had an extracted file, install it into the destination directory with
  # the proper name.
  if [ -f "${_dstdir}/${TARINSTALL_EXTRACT}" ]; then
    chmod a+x "${_dstdir}/${TARINSTALL_EXTRACT}"
    if [ -z "$TARINSTALL_PACKAGE" ]; then
      verbose "Installing as ${TARINSTALL_DESTDIR%%*/}/${TARINSTALL_BIN}"
      mv -f "${TMPD}/${TARINSTALL_EXTRACT}" "${TARINSTALL_DESTDIR%%*/}/${TARINSTALL_BIN}"
      rm -rf "$TMPD"
    else
      verbose "Installing as ${TARINSTALL_DESTDIR%%*/}/${TARINSTALL_BIN}, linked into package at ${TARINSTALL_PACKAGE%%*/}"
      ln -sf "${TARINSTALL_PACKAGE%%*/}/${TARINSTALL_EXTRACT}" "${TARINSTALL_DESTDIR%%*/}/${TARINSTALL_BIN}"
    fi
  else
    doexit "Could not find ${TMPD}/${TARINSTALL_EXTRACT}"
  fi
}

# No temporary directory at start, will be created as soon as have to download
# something.
TMPD=
if [ "$#" != "1" ]; then
  doexit "You must specify a URL to install from!"
fi

TARNAME=$(basename "$1")
[ -z "$TARINSTALL_EXTRACT" ] && TARINSTALL_EXTRACT=${TARNAME%%.*}
[ -z "$TARINSTALL_BIN" ] && TARINSTALL_BIN=$(basename "$TARINSTALL_EXTRACT")

TARINSTALL_KEEP=$(howlong "$TARINSTALL_KEEP")
if [ -f "${TARINSTALL_DESTDIR%%*/}/${TARINSTALL_BIN}" ]; then
  if [ -n "$TARINSTALL_KEEP" ] && [ "$TARINSTALL_KEEP" -gt "0" ]; then
    last=$(stat -c "%Z" "${TARINSTALL_DESTDIR%%*/}/${TARINSTALL_BIN}")
    # Get the current number of seconds since the epoch, POSIX compliant:
    # https://stackoverflow.com/a/12746260
    now=$(PATH=$(getconf PATH) awk 'BEGIN{srand();print srand()}')
    elapsed=$(( now - last ))
    if [ "$elapsed" -gt "$TARINSTALL_KEEP" ]; then
      verbose "File at ${TARINSTALL_DESTDIR%%*/}/${TARINSTALL_BIN} $elapsed secs. (too) old, installing again."
      tarinstall "$1"
    else
      verbose "File at ${TARINSTALL_DESTDIR%%*/}/${TARINSTALL_BIN} $elapsed secs. old, keeping."
    fi
  else
    verbose "Cache time $TARINSTALL_KEEP negative (or invalid), installing"
    tarinstall "$1"
  fi
else
  verbose "No file at ${TARINSTALL_DESTDIR%%*/}/${TARINSTALL_BIN}, installing"
  tarinstall "$1"
fi


# Print location of installed binary
[ -f "${TARINSTALL_DESTDIR%%*/}/${TARINSTALL_BIN}" ] && printf %s\\n "${TARINSTALL_DESTDIR%%*/}/${TARINSTALL_BIN}"
