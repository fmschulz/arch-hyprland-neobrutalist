#!/bin/bash

# Handle USB block device add/remove events and mount them to predictable
# /mnt/usb{n} directories based on their physical USB-C port number.

set -euo pipefail

CONFIG_FILE=/etc/arch-hypr-neobrutalist/usb-automount.conf
LOG_TAG="arch-usb-automount"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  /usr/bin/logger -t "${LOG_TAG}" "Config ${CONFIG_FILE} missing; skipping event for ${2:-unknown}"
  exit 0
fi

# shellcheck disable=SC1090
source "${CONFIG_FILE}"

MOUNT_ROOT=${MOUNT_ROOT:-/mnt}
MOUNT_PREFIX=${MOUNT_PREFIX:-usb}
STATE_DIR=${STATE_DIR:-/run/arch-hypr-neobrutalist-usb}
MOUNT_OPTIONS=${MOUNT_OPTIONS:-noatime}
AUTOMOUNT_USER=${AUTOMOUNT_USER:-}
AUTOMOUNT_GROUP=${AUTOMOUNT_GROUP:-${AUTOMOUNT_USER}}

if (( $# < 2 )); then
  /usr/bin/logger -t "${LOG_TAG}" "Unexpected arguments: ACTION=${1:-unset} DEV=${2:-unset}"
  exit 1
fi

ACTION=$1
KERNEL_NAME=$2
DEVNODE="/dev/${KERNEL_NAME}"

mkdir -p "${STATE_DIR}"

if [[ "${ACTION}" == "add" ]]; then
  for _ in {1..10}; do
    [[ -b "${DEVNODE}" ]] && break
    /bin/sleep 0.2
  done

  if [[ ! -b "${DEVNODE}" ]]; then
    /usr/bin/logger -t "${LOG_TAG}" "${DEVNODE} is not a block device"
    exit 1
  fi

  if [[ ${DEVTYPE:-} != "partition" ]]; then
    exit 0
  fi

  if [[ ${ID_FS_USAGE:-} != "filesystem" ]]; then
    exit 0
  fi

  sys_path=$(/usr/bin/readlink -f "/sys/class/block/${KERNEL_NAME}") || {
    /usr/bin/logger -t "${LOG_TAG}" "Unable to resolve sysfs path for ${KERNEL_NAME}"
    exit 1
  }

  port_segment=$(echo "${sys_path}" | /usr/bin/grep -oE '/[0-9]+-[0-9]+(\.[0-9]+)*' | /usr/bin/head -n1 || true)

  if [[ -z "${port_segment}" ]]; then
    /usr/bin/logger -t "${LOG_TAG}" "Unable to derive USB port for ${KERNEL_NAME}"
    exit 1
  fi

  port_base=${port_segment#*-}
  port=${port_base%%.*}

  if ! [[ "${port}" =~ ^[0-9]+$ ]]; then
    /usr/bin/logger -t "${LOG_TAG}" "Derived port '${port}' is not numeric for ${KERNEL_NAME}"
    exit 1
  fi

  mount_point="${MOUNT_ROOT}/${MOUNT_PREFIX}${port}"

  if /usr/bin/mountpoint -q "${mount_point}"; then
    /usr/bin/logger -t "${LOG_TAG}" "${mount_point} already mounted; skipping ${KERNEL_NAME}"
    exit 0
  fi

  /usr/bin/mkdir -p "${mount_point}"

  uid=""
  gid_num=""
  group_name="${AUTOMOUNT_GROUP}"
  if [[ -n "${AUTOMOUNT_USER}" ]]; then
    uid=$(/usr/bin/id -u "${AUTOMOUNT_USER}" 2>/dev/null || true)
    gid_value="${AUTOMOUNT_GROUP}"
    if [[ -n "${gid_value}" ]]; then
      gid_num=$(/usr/bin/getent group "${gid_value}" | /usr/bin/cut -d: -f3)
    fi
    if [[ -z "${gid_num}" && -n "${AUTOMOUNT_USER}" ]]; then
      gid_num=$(/usr/bin/id -g "${AUTOMOUNT_USER}" 2>/dev/null || true)
    fi
  fi

  fs_type=${ID_FS_TYPE:-}
  ro_fs=0
  if [[ ${ID_FS_READONLY:-0} == 1 || ${fs_type} == "iso9660" || ${fs_type} == "udf" ]]; then
    ro_fs=1
  fi

  IFS=',' read -ra configured_opts <<<"${MOUNT_OPTIONS}"
  declare -a mount_opts_arr=()
  for opt in "${configured_opts[@]}"; do
    opt=${opt// /}
    [[ -z "${opt}" ]] && continue
    if (( ro_fs )) && [[ "${opt}" == "rw" ]]; then
      continue
    fi
    mount_opts_arr+=("${opt}")
  done

  if (( ro_fs )); then
    mount_opts_arr=("ro" "${mount_opts_arr[@]}")
  fi

  if [[ -n "${uid}" && -n "${gid_num}" ]]; then
    case "${fs_type}" in
      vfat|msdos|exfat)
        mount_opts_arr+=("uid=${uid}" "gid=${gid_num}" "dmask=022" "fmask=133")
        ;;
      ntfs|ntfs3)
        mount_opts_arr+=("uid=${uid}" "gid=${gid_num}")
        ;;
    esac
  fi

  if (( ${#mount_opts_arr[@]} )); then
    mount_opts_joined=$(IFS=','; printf '%s' "${mount_opts_arr[*]}")
    /usr/bin/mount -o "${mount_opts_joined}" "${DEVNODE}" "${mount_point}"
  else
    /usr/bin/mount "${DEVNODE}" "${mount_point}"
  fi

  if (( ! ro_fs )) && [[ -n "${AUTOMOUNT_USER}" && -n "${group_name}" ]]; then
    /usr/bin/chown "${AUTOMOUNT_USER}:${group_name}" "${mount_point}" || true
  fi

  if (( ! ro_fs )); then
    /usr/bin/chmod 755 "${mount_point}" || true
  fi

  echo "${mount_point}" >"${STATE_DIR}/${KERNEL_NAME}"

  /usr/bin/logger -t "${LOG_TAG}" "Mounted ${DEVNODE} (${fs_type:-unknown}) at ${mount_point}"
  exit 0
fi

if [[ "${ACTION}" == "remove" ]]; then
  state_file="${STATE_DIR}/${KERNEL_NAME}"
  if [[ -f "${state_file}" ]]; then
    mount_point=$(/usr/bin/cat "${state_file}")
  else
    mount_point=$(/usr/bin/mount | /usr/bin/awk -v dev="${DEVNODE}" '$1==dev {print $3}' | /usr/bin/head -n1)
  fi

  if [[ -n "${mount_point}" && -d "${mount_point}" ]]; then
    if /usr/bin/mountpoint -q "${mount_point}"; then
      /usr/bin/umount "${mount_point}" || {
        /usr/bin/logger -t "${LOG_TAG}" "Failed to unmount ${mount_point} for ${KERNEL_NAME}"
      }
    fi
    /usr/bin/rmdir "${mount_point}" 2>/dev/null || true
  fi

  /usr/bin/rm -f "${STATE_DIR}/${KERNEL_NAME}" 2>/dev/null || true
  /usr/bin/logger -t "${LOG_TAG}" "Detached ${DEVNODE}; cleaned up ${mount_point:-unknown}"
fi

exit 0
