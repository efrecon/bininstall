#!/usr/bin/env sh

# Destination directory for the installation of the final binary.
BININSTALL_DESTDIR=${BININSTALL_DESTDIR:-"/usr/local/bin"}

# Name of the binary to place under $TARINSTALL_DESTDIR. When empty, the
# default, this will be the basename of the installation URL.
BININSTALL_BIN=${BININSTALL_BIN:-""}

# Period to keep destination binary in cache without even triggering a download
# attempt. Default to 0, always download. This can be a human-readable period
# such as 3d (3 days), etc.
BININSTALL_KEEP=${BININSTALL_KEEP:-0}

# Set this to 1 for increased verbosity
BININSTALL_VERBOSE=${BININSTALL_VERBOSE:-0}

verbose() {
  [ "$BININSTALL_VERBOSE" = "1" ] && printf %s\\n "$1" >&2
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
      BININSTALL_DESTDIR=$2; shift 2;;
    --dest=* | --destination=*)
      BININSTALL_DESTDIR="${1#*=}"; shift 1;;

    -b | --bin | --binary)
      BININSTALL_BIN=$2; shift 2;;
    --bin=* | --binary=*)
      BININSTALL_BIN="${1#*=}"; shift 1;;

    -k | --keep)
      BININSTALL_KEEP=$2; shift 2;;
    --keep=*)
      BININSTALL_KEEP="${1#*=}"; shift 1;;

    -v | --verbose)
      BININSTALL_VERBOSE=1; shift;;

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

bininstall() {
  TMPD=$(mktemp -d)
  download "$1" "${TMPD}/${BININSTALL_BIN}"

  # If we had a downloaded file, install it into the destination directory with
  # the proper name.
  if [ -f "${TMPD}/${BININSTALL_BIN}" ]; then
    chmod a+x "${TMPD}/${BININSTALL_BIN}"
    verbose "Installing as ${BININSTALL_DESTDIR%/}/${BININSTALL_BIN}"
    mv -f "${TMPD}/${BININSTALL_BIN}" "${BININSTALL_DESTDIR%%*/}/${BININSTALL_BIN}"
    rm -rf "$TMPD"
  else
    doexit "Could not download from $1 to ${TMPD}/${BININSTALL_BIN}"
  fi
}

# No temporary directory at start, will be created as soon as have to download
# something.
TMPD=
if [ "$#" != "1" ]; then
  doexit "You must specify a URL to install from!"
fi

[ -z "$BININSTALL_BIN" ] && BININSTALL_BIN=$(basename "$1")

BININSTALL_KEEP=$(howlong "$BININSTALL_KEEP")
if [ -f "${BININSTALL_DESTDIR%%*/}/${BININSTALL_BIN}" ]; then
  if [ -n "$BININSTALL_KEEP" ] && [ "$BININSTALL_KEEP" -gt "0" ]; then
    last=$(stat -c "%Z" "${BININSTALL_DESTDIR%%*/}/${BININSTALL_BIN}")
    # Get the current number of seconds since the epoch, POSIX compliant:
    # https://stackoverflow.com/a/12746260
    now=$(PATH=$(getconf PATH) awk 'BEGIN{srand();print srand()}')
    elapsed=$(( now - last ))
    if [ "$elapsed" -gt "$BININSTALL_KEEP" ]; then
      verbose "File at ${BININSTALL_DESTDIR%%*/}/${BININSTALL_BIN} $elapsed secs. (too) old, installing again."
      bininstall "$1"
    else
      verbose "File at ${BININSTALL_DESTDIR%%*/}/${BININSTALL_BIN} $elapsed secs. old, keeping."
    fi
  else
    verbose "Cache time $BININSTALL_KEEP negative (or invalid), installing"
    bininstall "$1"
  fi
else
  verbose "No file at ${BININSTALL_DESTDIR%%*/}/${BININSTALL_BIN}, installing"
  bininstall "$1"
fi

# Print location of installed binary
[ -f "${BININSTALL_DESTDIR%%*/}/${BININSTALL_BIN}" ] && printf %s\\n "${BININSTALL_DESTDIR%%*/}/${BININSTALL_BIN}"
