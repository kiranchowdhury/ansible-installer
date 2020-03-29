#!/bin/bash
#------------------------------------------------------------------------------
# Script:  installer
#------------------------------------------------------------------------------
# Author: Kiran S Chowdhury
#------------------------------------------------------------------------------
# Installer to run the initial setup the Ansible Controller Machine
#------------------------------------------------------------------------------

VERSION="1.0.1"
PROG="ePricer"
INSTALLER_URL=""
OPS_CLONE_URL="git@github.ibm.com:operation-squads/operator.git"
GIT_URL="git url"
SLACK_URL="next slack url"


#------------------------------------------------------------------------------
function help {
  cat <<-!!EOF

  ${PROG}
  Usage: idt-installer [<args>]

  Where <args> is:
    install          [Default] Perform full install (or update) of all needed CLIs and Plugins
    help | -h | -?   Show this help
    --force          Force updates of dependencies and other settings during update
    --trace          Eanble verbose tracing of all activity

  If "install" (or no action provided), a full installation (or update) will occur:
  1. Pre-req check for 'git'
  2. Install all required softwares - git, tree.

  Chat with us on Slack: ${SLACK_URL}, channel #developer-tools
  Submit any issues to : ${GIT_URL}/issues

	!!EOF
}


#------------------------------------------------------------------------------
#-- ${FUNCNAME[1]} == Calling function's name
#-- Colors escape seqs
YEL='\033[1;33m'
CYN='\033[0;36m'
GRN='\033[1;32m'
RED='\033[1;31m'
NRM='\033[0m'

function log {
  echo -e "${CYN}[${FUNCNAME[1]}]${NRM} $*"
}

function warn {
  echo -e "${CYN}[${FUNCNAME[1]}]${NRM} ${YEL}WARN${NRM}: $*"
}

function error {
  echo -e "${CYN}[${FUNCNAME[1]}]${NRM} ${RED}ERROR${NRM}: $*"
  exit -1
}

function prompt {
  label=${1}
  default=${2}
  if [[ -z $default ]]; then
    echo -en "${label}: ${CYN}" > /dev/tty
  else
    echo -en "${label} [$default]: ${CYN}"  > /dev/tty
  fi
  read -r
  echo -e "${NRM}"  > /dev/tty
  #-- Use $REPLY to get user's input
}

#------------------------------------------------------------------------------
function install {
  if [[ -n "$(which ansible)" ]]; then
    log "Starting Installation..."
  else
    log "Starting Update..."
  fi

  [ "$SUDO" ] && log "Note: You may be prompted for your 'sudo' password during install."

  install_deps
  log "Install finished."
  log "Starting setup."
  createAnsibleAdmin
  git_add_ssh_key
  cloneOpsRepo
}

#------------------------------------------------------------------------------
function install_deps {
  #-- check for/install brew for macos
  case "$PLATFORM" in
  "Linux")
    if [[ "${DISTRO}" == *Ubuntu* || "${DISTRO}" == *Debian* ]]; then
      install_deps_with_apt_get
    elif [[ "${DISTRO}" == *Red*Hat* || "${DISTRO}" == *CentOS* || "${DISTRO}" == *RHEL* || "${DISTRO}" == *Fedora* ]]; then
      install_deps_with_yum
    else
      error "This script has not been updated for use with your linux distribution (${DISTRO})"
    fi
    ;;
  esac

}


#------------------------------------------------------------------------------
function install_deps_with_yum {
    log "Checking for and updating 'yum' support on Linux"
    if [[ -z "$(which yum)" ]]; then
      error "'yum' is not found.  That's the only RedHat/Centos linux installer I know, sorry."
    fi

    #-- CURL:
    log "Installing/updating external dependency: curl"
    if [[ -z "$(which curl)" || "$FORCE" == true ]]; then
      $SUDO yum -y install curl
    fi
    #-- GIT:
    log "Installing/updating external dependency: git"
    if [[ -z "$(which git)" || "$FORCE" == true ]]; then
      $SUDO yum install -y git
      log  "Please review any setup requirements for 'git' from: https://git-scm.com/downloads"
    fi

    #-- Tree:
    log "Installing/updating external dependency: tree"
    if [[ -z "$(which ansible)" || "$FORCE" == true ]]; then
      $sudo yum install -y tree
      log  "Tree installed successfully"
    fi

    #-- Ansible:
    log "Installing/updating external dependency: ansible"
    if [[ -z "$(which ansible)" || "$FORCE" == true ]]; then
      $sudo yum install -y ansible
      log  "Please review any information for 'ansible' from: https://www.ansible.com/resources/get-started"
    fi
}

function install_deps_with_apt_get {
    log "Checking for and updating 'apt-get' support on Linux"
    if [[ -z "$(which apt-get)" ]]; then
      error "'apt-get' is not found.  That's the only Debian/Ubuntu linux installer I know, sorry."
    fi
    $SUDO apt-get -y -qq update > /dev/null
    if [[ -z "$(which add-apt-repository)" ]]; then
      if [ "$(apt-cache search software-properties-common | wc -l)" != "0" ]; then
        log "Installing package: software-properties-common"
        $SUDO apt-get install -yqq software-properties-common > /dev/null 2>&1
      fi
      if [ "$(apt-cache search python-software-properties | wc -l)" != "0" ]; then
        log "Installing package: python-software-properties"
        $SUDO apt-get install -yqq python-software-properties > /dev/null 2>&1
      fi
    fi
    $SUDO add-apt-repository -y ppa:git-core/ppa
    $SUDO apt-get -y update

    #-- CURL:
    log "Installing/updating external dependency: curl"
    if [[ -z "$(which curl)" || "$FORCE" == true ]]; then
      $SUDO apt-get -y install curl
    fi

    #-- GIT:
    log "Installing/updating external dependency: git"
    if [[ -z "$(which git)" || "$FORCE" == true ]]; then
      $SUDO apt-get -y install git
      log  "Please review any setup requirements for 'git' from: https://git-scm.com/downloads"
    fi

    #-- ANSIBLE:
    log "Installing/updating external dependency: ansible"
    if [[ -z "$(which ansible)" || "$FORCE" == true ]]; then
      $sudo apt update
      $sudo apt-add-repository --yes --update ppa:ansible/ansible
      $sudo apt install ansible
      log  "Please review any information for 'ansible' from: https://www.ansible.com/resources/get-started"
    fi
}

#------------------------------------------------------------------------------
# Create Ansible Admin
#------------------------------------------------------------------------------
function createAnsibleAdmin {
  log "Creating ansible admin ansadmin"
  $sudo useradd ansadmin
  $sudo passwd ansadmin
}

#------------------------------------------------------------------------------
# Configure Git For Ansible Admin
#------------------------------------------------------------------------------
function git_add_ssh_key {
  log "Configuring git for ansadmin.."
  read -p "Enter github email : " email
  log "Using email $email"
  warn "(MAKE SURE TO GENERATE THE SSH KEY UNDER /home/ansadmin/.ssh)"
  if [ ! -f /home/ansadmin/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -C "$email"
    ssh-add /home/ansadmin/.ssh/id_rsa
  fi
  pub=`cat /home/ansadmin/.ssh/id_rsa.pub`
  read -p "Enter github username: " githubuser
  log "Using username $githubuser"
  read -s -p "Enter github password for user $githubuser: " githubpass
  curl -u "$githubuser:$githubpass" -X POST -d "{\"title\":\"`hostname`\",\"key\":\"$pub\"}" https://github.ibm.com/api/v3/user/keys
  $sudo chown -R ansadmin:ansadmin /home/ansadmin/.ssh
}

#------------------------------------------------------------------------------
# Configure Git For Ansible Admin
#------------------------------------------------------------------------------
function cloneOpsRepo {
  git clone ${OPS_CLONE_URL} /home/ansadmin/workspace/operator
  $sudo chown -R ansadmin:ansadmin /home/ansadmin/workspace
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------
function main {
  log "--==[ ${GRN}${PROG}, v${VERSION}${NRM} ]==--"
  (( SECS = SECONDS ))

  TMPDIR=${TMPDIR:-"/tmp"}
  PLATFORM=$(uname)
  ACTION=""

  # Only use sudo if not running as root:
  [ "$(id -u)" -ne 0 ] && SUDO=sudo || SUDO=""

  #-- Parse args
  while [[ $# -gt 0 ]]; do
    case "$1" in
    "--trace")
      warn "Enabling verbose tracing of all activity"
      set -x
      ;;
    "--force")
      FORCE=true
      warn "Forcing updates for all dependencies and other settings"
      ;;
    "update")     ACTION="install";;
    "install")    ACTION="install";;
    "help")       ACTION="help";;
    esac
    shift
  done

  case "$PLATFORM" in
  "Darwin")
    ;;
  "Linux")
    # Linux distro, e.g "Ubuntu", "RedHatEnterpriseWorkstation", "RedHatEnterpriseServer", "CentOS", "Debian"
    DISTRO=$(lsb_release -ds 2>/dev/null || cat /etc/*release 2>/dev/null | head -n1 || uname -om || echo "")
    if [[ "$DISTRO" != *Ubuntu* &&  "$DISTRO" != *Red*Hat* && "$DISTRO" != *CentOS* && "$DISTRO" != *Debian* && "$DISTRO" != *RHEL* && "$DISTRO" != *Fedora* ]]; then
      warn "Linux has only been tested on Ubuntu, RedHat, Centos, Debian and Fedora distrubutions please let us know if you use this utility on other Distros"
    fi
    ;;
  *)
    warn "Only Linux systems are supported by this installer."
    error "Unsupported platform: ${PLATFORM}"
    ;;
  esac

  case "$ACTION" in
  "")           install;;
  "install")    install;;
  *)            help;;
  esac

  (( SECS = SECONDS - SECS ))
  log "--==[ ${GRN}Total time: ${SECS} seconds${NRM} ]==--"
}

#------------------------------------------------------------------------------
#-- Kick things off
#------------------------------------------------------------------------------
main "$@"
