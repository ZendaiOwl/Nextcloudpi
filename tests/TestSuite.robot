#!/usr/bin/env python3

*** Settings ***
Library         OperatingSystem
Library         Collections
Library         OperatingSystem
Library         Process
Library         String
Library         Telnet
Library         XML

*** Variables ***
${ROOTDIR}                      ${CURDIR}/../

${BUILD_DIR}                    ${ROOTDIR}/build
${ARMBIAN_DIR}                  ${BUILD_DIR}/armbian
${DOCKER_DIR}                   ${BUILD_DIR}/docker
${DEBIAN-NCP_DOCKER_DIR}        ${DOCKER_DIR}/debian-ncp
${LAMP_DOCKER_DIR}              ${DOCKER_DIR}/lamp
${NEXTCLOUD_DOCKER_DIR}         ${DOCKER_DIR}/nextcloud
${NEXTCLOUDPI_DOCKER_DIR}       ${DOCKER_DIR}/nextcloudpi

${ETC_DIR}                      ${ROOTDIR}/etc
${NCP_CONFIG_DIR}               ${ETC_DIR}/ncp-config.d
${NCP_TEMPLATES_DIR}            ${ETC_DIR}/ncp-templates
${TEMPLATE_DIR_APACHE2}         ${NCP_TEMPLATES_DIR}/apache2
${TEMPLATE_DIR_MYSQL}           ${NCP_TEMPLATES_DIR}/mysql
${TEMPLATE_DIR_PHP}             ${NCP_TEMPLATES_DIR}/php
${TEMPLATE_DIR_SYSTEMD}         ${NCP_TEMPLATES_DIR}/systemd

${BIN_DIR}                      ${CURDIR}/../bin
        
${LOCAL_ETC_DIR}                /usr/local/etc
${LOCAL_BIN_DIR}                /usr/local/bin

${BUILDLIB}                     ${BUILD_DIR}/buildlib.sh
${LIBRARY}                      ${ROOTDIR}/etc/library.sh

${SCRIPT_NCP}                   ${ROOTDIR}/ncp.sh
${SCRIPT_INSTALL}               ${ROOTDIR}/install.sh
${SCRIPT_LAMP}                  ${ROOTDIR}/lamp.sh
${SCRIPT_UPDATE}                ${ROOTDIR}/update.sh
${SCRIPT_POST-INST}             ${ROOTDIR}/post-inst.sh

${SCRIPT_TEMPLATE_NEXTCLOUD}    ${NCP_TEMPLATES_DIR}/nextcloud.conf.sh

${BUILD_SD_RPI}                 ${BUILD_DIR}/build-SD-rpi.sh

# ${}               ${CURDIR}/../

# ${CFGDIR}          ${CURDIR}/

# ${HTTP_DIR}        /var/www
# ${NCDIR}           ${HTTP_DIR}/nextcloud

# ${}               ${CURDIR}/../

*** Test Cases ***
NCP Directories
    Log                        "Checking for directories"
    Directory Should Exist     ${BUILD_DIR}
    Directory Should Exist     ${ARMBIAN_DIR}
    Directory Should Exist     ${DOCKER_DIR}
    Directory Should Exist     ${DEBIAN-NCP_DOCKER_DIR}
    Directory Should Exist     ${LAMP_DOCKER_DIR}
    Directory Should Exist     ${NEXTCLOUD_DOCKER_DIR}
    Directory Should Exist     ${NEXTCLOUDPI_DOCKER_DIR}

    Directory Should Exist     ${ETC_DIR}
    Directory Should Exist     ${NCP_CONFIG_DIR}
    Directory Should Exist     ${NCP_TEMPLATES_DIR}
    Directory Should Exist     ${TEMPLATE_DIR_APACHE2}
    Directory Should Exist     ${TEMPLATE_DIR_MYSQL}
    Directory Should Exist     ${TEMPLATE_DIR_PHP}
    Directory Should Exist     ${TEMPLATE_DIR_SYSTEMD}

    Directory Should Exist     ${BIN_DIR}
    Directory Should Exist     ${LOCAL_ETC_DIR}
    Directory Should Exist     ${LOCAL_BIN_DIR}

NCP Build Files
    Log                         "Checking for build files"
    File Should Exist           ${BUILDLIB}
    File Should Exist           ${BUILDLIB}

NCP Files: libraries      
    Log                         "Checking for library files"
    File Should Exist           ${BUILDLIB}
    File Should Exist           ${BUILD_SD_RPI}

NCP Files: scripts      
    Log                         "Checking for script files"
    File Should Exist           ${SCRIPT_NCP}
    File Should Exist           ${SCRIPT_INSTALL}
    File Should Exist           ${SCRIPT_LAMP}
    File Should Exist           ${SCRIPT_UPDATE}
    File Should Exist           ${SCRIPT_POST-INST}
    File Should Exist           ${SCRIPT_TEMPLATE_NEXTCLOUD}


