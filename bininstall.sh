#!/usr/bin/env sh

# Destination directory for the installation of the final binary.
BININSTALL_DESTDIR=${BININSTALL_DESTDIR:-"/usr/local/bin"}

# Name of the binary to place under $TARINSTALL_DESTDIR. When empty, the
# default, this will be the basename of the installation URL.
BININSTALL_BIN=${BININSTALL_BIN:-""}

# Set this to 1 for increased verbosity
BININSTALL_VERBOSE=${BININSTALL_VERBOSE:-0}

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

    -v | --verbose)
      BININSTALL_VERBOSE=1; shift;;

    --)
      shift; break;;
    -*)
      usage "Unknown option: $1 !";;
    *)
      break;;
  esac
done

verbose() {
  [ "$BININSTALL_VERBOSE" = "1" ] && printf %s\\n "$1" >&2
}
errlog() {
  printf %s\\n "$1" >&2
}
download() {
  verbose "Downloading $1"
  if command -v curl >&2 >/dev/null; then
    curl -sSL "$1" > "$2"
  elif command -v wget >&2 >/dev/null; then
    wget -q -O - "$1" > "$2"
  else
    errlog "Can neither find curl, nor wget for downloading"
    return 1
  fi
}

if [ "$#" != "1" ]; then
  errlog "You must specify a URL to install from!"
  exit 1
fi

[ -z "$BININSTALL_BIN" ] && BININSTALL_BIN=$(basename "$1")


TMPDIR=$(mktemp -d)
download "$1" "${TMPDIR}/${BININSTALL_BIN}"
if ! [ -f "${TMPDIR}/${BININSTALL_BIN}" ]; then
  errlog "Could not download from $1 to ${TMPDIR}/${BININSTALL_BIN}"
  exit 1
fi
chmod a+x "${TMPDIR}/${BININSTALL_BIN}"
verbose "Installing as ${BININSTALL_DESTDIR%/}/${BININSTALL_BIN}"
mv -f "${TMPDIR}/${BININSTALL_BIN}" "${BININSTALL_DESTDIR%/}/${BININSTALL_BIN}"
rm -rf "$TMPDIR"
