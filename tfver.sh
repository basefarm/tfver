#!/bin/bash
function _tfver_usage() {
  echo "Usage: tfver [-h|-l|-i|-u|-c] [version]"
  echo ""
  echo "  -h        Displays this usage information."
  echo "  -l        List the Terraform versions available."
  echo "  -i        Install the systemwide-hook that enables tfver for all uses when logging in."
  echo "            (NB This requires root priviledges.)"
  echo "  -u        Add a new version of Terraform to the list of available versions."
  echo "            (NB This may require root priviledges.)"
  echo "  -c        Configure a personal preference for a specific version."
  echo "            This creates a .tfverrc file in your homedirectory"
  echo "  version   The version of Terraform that you wish to use or download."
  echo "            If you leave this blank, the default/latest version will be used"
}
function tfver() {
  tfver_globstate=`shopt -p extglob`
  unset CDPATH
  shopt -s extglob
  local OPTIND ; local TFVERINSTALL=0 ; local TFVERUPGRADE=0 ; local TFVERLIST=0 ; local TFVERCONFIGURE ; local TFVERBASEDIR ; local TFVERDEFAULT

  while getopts ":cdhilu" opt ; do
		case "$opt" in
			h		) _tfver_usage ; return 0 ;;
			i		) TFVERINSTALL=1 ;;
			l		) TFVERLIST=1 ;;
      u   ) TFVERUPGRADE=1 ;;
      c   ) TFVERCONFIGURE=1 ;;
      d   ) DEBUG=1 ;;
			\?	) echo "Invalid option: -$OPTARG" >&2 ;;
			:		) echo "Option -$OPTARG requires an argument." >&2 ; exit 1 ;;
    esac
  done
  shift $((OPTIND-1))

  if test -z "$(readlink "${BASH_SOURCE}")" ; then
    local tmpdir="$(dirname "${BASH_SOURCE}")"
  else
    local tmpdir="$(dirname "$(readlink "${BASH_SOURCE}")")"
  fi
  pushd $tmpdir &>/dev/null
  TFVERBASEDIR=`pwd`
	if (( DEBUG )) ; then echo "TFVERBASEDIR = ${TFVERBASEDIR}" ; fi
  popd &>/dev/null

  if (( TFVERUPGRADE )) ; then
    local USESUDO=0
    echo "# Upgrading"
    if ! test -d "${TFVERBASEDIR}/binlib" ; then
      if test -w "${TFVERBASEDIR}" ; then
        mkdir -p "${TFVERBASEDIR}/binlib"
      else
        if sudo -n true &>/dev/null ; then
          sudo mkdir -p "${TFVERBASEDIR}/binlib"
        else
          "# ERROR: cannot create folder ${TFVERBASEDIR}/binlib, so upgrade cannot be performed"
          return 1
        fi
      fi
    fi
    if ! test -w "${TFVERBASEDIR}/binlib" ; then
      if sudo -n true &>/dev/null ; then
        USESUDO=1
      else
        "# ERROR: cannot write to ${TFVERBASEDIR}/binlib, so upgrade cannot be performed"
        return 1
      fi
    fi

    if test -z $1 ; then
      local MYURL="$(curl -s https://www.terraform.io/downloads.html | grep -o -P "href=[\"']\K[^'\"]+(?=[\"']>64-bit)" | grep _linux_amd64.zip)"
      local MYDLVER="$(echo $MYURL | cut -d '/' -f 5)"
    else
      local MYDLVER="${1}"
      local MYURL="https://releases.hashicorp.com/terraform/${MYDLVER}/terraform_${MYDLVER}_linux_amd64.zip"
    fi
    if test -z $2 ; then
      local MYMINOR="$(echo $MYDLVER | rev | cut -d '.' -f 2- | rev)"
    else
      local MYMINOR="${2}"
    fi
		if (( DEBUG )) ; then echo "MYDLVER = ${MYDLVER}" ; echo "MYMINOR = ${MYMINOR}" ; fi
    local MYTMPFILE="$(mktemp)"
    curl -so "${MYTMPFILE}" "${MYURL}"
    if test -d "${TFVERBASEDIR}/binlib/${MYMINOR}" ; then
      if test "$("${TFVERBASEDIR}/binlib/${MYMINOR}/terraform" version|awk '{print $2}')" = "v${MYDLVER}" ; then
        echo "# INFO: ${MYDLVER} already exists, nothing to do."
        return 0
      fi
    else
      if (( USESUDO )) ; then
        sudo mkdir -p "${TFVERBASEDIR}/binlib/${MYMINOR}"
      else
        mkdir -p "${TFVERBASEDIR}/binlib/${MYMINOR}"
      fi
    fi
    if (( USESUDO )) ; then
      if test -x "${TFVERBASEDIR}/binlib/${MYMINOR}/terraform" ; then
        sudo rm -f "${TFVERBASEDIR}/binlib/${MYMINOR}/terraform"
      fi
      sudo unzip -qud "${TFVERBASEDIR}/binlib/${MYMINOR}" "${MYTMPFILE}"
    else
      if test -x "${TFVERBASEDIR}/binlib/${MYMINOR}/terraform" ; then
        rm -f "${TFVERBASEDIR}/binlib/${MYMINOR}/terraform"
      fi
      unzip -qud "${TFVERBASEDIR}/binlib/${MYMINOR}" "${MYTMPFILE}"
    fi
    rm -f "${MYTMPFILE}"
  fi

  test -r ${TFVERBASEDIR}/etc/config && . ${TFVERBASEDIR}/etc/config
  test -r ~/.tfverrc && . ~/.tfverrc

  if test -z "${TFVERDEFAULT}" ; then
    TFVERDEFAULT="$(ls -1 ${TFVERBASEDIR}/binlib/*/terraform | rev | cut -d '/' -f 2 | rev|sort --version-sort | tail -n 1)"
    if test -z "${TFVERDEFAULT}" ; then
      [[ $- =~ i ]] && echo "ERROR: No versions of Terraform found in ${TFVERBASEDIR}/binlib"
    fi
  fi

  if ! echo "${PATH}" | grep -q "${TFVERBASEDIR}/binlib" ; then
    PATH="${PATH}:${TFVERBASEDIR}/binlib/${TFVERDEFAULT}"
  fi

  if (( TFVERLIST )) ; then
    echo -en "# Versions available: "
    ls -1 ${TFVERBASEDIR}/binlib/*/terraform | rev | cut -d '/' -f 2 | rev | sort --version-sort | xargs echo
    test -d ${TFVERBASEDIR}/binlib/${TFVERDEFAULT} || echo "# Warning: Terraform version ${TFVERDEFAULT} is set as the default version, but it doesn't seem to exist in ${TFVERBASEDIR}/binlib"
    return 0
  fi

  if (( TFVERINSTALL )) ; then
    echo "# Installing"
    if test -w /etc/profile.d ; then
      ln "${TFVERBASEDIR}/tfver.sh" -sfbn /etc/profile.d/tfver.sh
    else
      if sudo -n true &>/dev/null ; then 
        sudo ln "${TFVERBASEDIR}/tfver.sh" -sfbn /etc/profile.d/tfver.sh
      else
        echo "# Warning: User $USER is not allowed to write to /etc/profile.d or use sudo, so this must be done manually by root:"
        echo "ln -sfbn \"${TFVERBASEDIR}/tfver\" /etc/profile.d/tfver.sh"
      fi
    fi
    return 0
  fi


  if (( TFVERCONFIGURE )) ; then
    if test -z $1 ; then
      if test -r ~/.tfverrc ; then
        if test -w ~/.tfverrc ; then
          echo "# INFO Unconfiguring userspecific version"
          rm -rf ~/.tfverrc
        else
          echo "ERROR Unable to unconfigure userspecific version. ~/.tfverrc not writable by user $USER"
          return 1
        fi
      else
        echo "# WARN no userspecifc version definition found, nothing to unconfigure."
      fi
    else
      if test -x "${TFVERBASEDIR}/binlib/${1}/terraform" ; then
        if test -w ~/ ; then
          echo "TFVERDEFAULT=${1}" > ~/.tfverrc
          echo "# INFO userspecific version set to $1"
          TFVERDEFAULT=${1}
        else
          echo "# ERROR Unable to configure userspecific version. ~/ not writable by user $USER"
          return 1
        fi
      else
        echo "# ERROR Unable to configure userspecific version. No version $1 available."
      fi
    fi
  fi
  local TFVER="${1:-${TFVERDEFAULT}}"
  if ! test -x "${TFVERBASEDIR}/binlib/${TFVER}/terraform" ; then
    [[ $- =~ i ]] && echo "# WARNING Version '$1' not found, using default instead. Use 'tfver -l' to see available versions"
    TFVER="${TFVERDEFAULT}"
  fi
  export PATH="${PATH//${TFVERBASEDIR}\/binlib\/*([a-z0-9.])/${TFVERBASEDIR}/binlib/${TFVER}}"
  eval ${tfver_globstate}
  unset tfver_globstate
  [[ $- =~ i ]] && terraform version
}
if test $UID -eq 0 ; then
  return 0
else
  tfver
fi

