#!/bin/bash  

# Matthieu Araman , Splunk 
# 20170906 version from staging version just to install initial ES app and launch setup
# 20170906 asking for splunk admin password
# 20171123 add explicit timeout for essinstall in case it is not already pushed via base apps
# 20171209 add more timeout cases , add check for result of essinstaller2.log , initial md5 sum verif
# 20180320 fix typo in tail command checking essinstaller2.log
# 20180822 add install app repo dir var
# 20180910 remove commented steps about TA, update comments, ask for login/password as inputs to avoid passwords typo in the middle of the script
# 20180910 add check for non root
# 20180911 include error logging functions, set log to sdtout, change md5 to sha256 for integrity checking
# 20181012 more logging function conversion, more messages, typo fix, add error loop protection for password, remove extra restart
# 20181119 comment out the password input , need to fix it before
# 20190115 add sha256 for 5.2.2
# 20190205 add auto detection for path, fix and reenable login detection so we loop and make sure the password is correct (to avoir half installation because of typo)
# 20190303 include es content update
# 20190422 add es 5.3
# 20190427 add Splunkd timeout check
# 20190507 remove local mac option to make it more generic, improve/fix comments, short log for direct screen output
# 20190904 add es5.3.1, add expectedsha var, propose customized dir when splunk_home was changed
# 20190904 add detection logic to force specify shc installation mode (5.3+ needed) as the installer doesnt automatically detect it is run from the shc
# 20190919 fix detection logic for shcluster
# 20190919 change essinstall order and move escontemtupdate install to shcluster/apps in shc mode
# 20190923 remove unused (and empty) var in setup command line 
# 20200116 add sha for 6.0
# 20200410 add more sha for 6.x, add info about permission change behavior with 8.x , add check that verify upload limits where increased + capabilities required by 8.0x + improve shc deployer detection
# 20200411 automate sha256 check and bail out if no match, change ES Content update detection and ask for fix is not there, add print sha256 for ES Content Update, more tests and fixes
# 20200412 add version check to autoadapt to the version and keep one single script for all versions, add prompt to continue installation and try to run all conditions even when failure to have the admin build faster the list of all things to fix, move some messages to debug log level 
# 20200416 add sha256 for ES 6.1.1 and make it default
# 20200508 add sha256 for ES6.2, use more relaxed regex for final check as the log sligthly changed with latest versions
# 20200629 fix shc test for ES content update, add ESINSTALLERNFORCENOTA and remove TA options fron essinstall for 6.2. change default to 6.2
# 20201103 add version var + fix typo in message
# 20201123 add sha for es6.4
# 20201215 update sha for 6.4 as the build was updated 
# 20210210 add sha for 6.4.1
# 20210706 add sha for 6.6.0
# 20210929 add sha for 6.6.2
# 20211004 add debug statement to try to catch TCPOutloop crash sometimes occuring with 8.2 during ES setup
# 20211217 add sha for 7.0.0
# 20220325 add sha for 7.0.1
# 20221009 add sha for 7.0.2
# 20230116 add sha for 7.1.0
# 20230118 improve messages
# 20230118 increase max_upload_size check to 2048 to match current ES doc and improve messages
# 20230118 add setting to not restart between install and setup 
# 20230530 add sha for 7.1.1
# 20230907 add sha for 7.2.0
# 20231220 add sha for 7.3.0
# 20240424 add sha for 7.3.1
# 20240612 add sha for 7.3.2
# 20240903 make ES content update optional 
# 20240903 allow user to still try installation even when some checks are failing
# 20240904 increase splunkdtimeout check and reco to 300s + improve error messages
# 20240914 add support to give optional argument for ESAPP and ESCU
# 20241003 trying to disable bracketed paste mode as it break pasting into the script (especially with recent macos terminal)
# 20241015 relax syntax check for installation confirmation 
# 20241020 change output order on essinstaller error check to make it easier to spot
# 20241020 more bracketed paste mode disabling
# 20241203 rework test logic at end of setup to improve messages and add crash.log detection and print log if detected
# 20241203 add info on splunk version in output
# 20250115 change sha check to warning if custom build used (because hardcoded sha wont match)
# 20250115 add choice to only do setup (in case installation already done but setup failed)
# 20250123 up to 8.0.2
# 20250505 add auto workaround for outputs reload that can lead to crash
# 20250611 up to 8.1.0
# 20250825 up to 8.1.1
# 20250825 adding variable for output reload workaround and disabling by default 
# 20250825 small workding updates
# 20251008 update to 8.2.3

VERSION="20251008a"

SCRIPTNAME="installes"

# set to no for newer ES versions
ESINSTALLERNFORCENOTA="no"

INSTALLWITHSETUP="yes"

# no or yes
ENABLEWORKAROUNDOUTPUTRELOAD="no"

###### function definition

function echo_log_ext {
    LANG=C
    #NOW=(date "+%Y/%m/%d %H:%M:%S")
    NOW=(date)
    # full version for logging and indexing log in splunk internal log
    # customize here if needed
    #LOGFILE="$SPLUNK_HOME/var/log/splunk/installesscript.log"
    #echo `$NOW`" ${SCRIPTNAME} $1 " >> $LOGFILE
    # shortest version for terminal output
    echo  $1 
}


function debug_log {
  #    echo_log_ext  "DEBUG id=$ID $1" 
  DEBUG=0
  if [ $DEBUG -eq 1 ]; then
    echo_log_ext  "$1" 
  fi
}

function echo_log {
  #    echo_log_ext  "INFO id=$ID $1" 
  echo_log_ext  "$1" 
}

function warn_log {
  #    echo_log_ext  "WARN id=$ID $1" 
  echo_log_ext  "WARN $1" 
}

function fail_log {
  #    echo_log_ext  "FAIL id=$ID $1" 
  echo_log_ext  "FAIL $1" 
}

###### start

# %u is day of week , we may use this for custom purge
TODAY=`date '+%Y%m%d-%H:%M_%u'`;
ID=`date '+%s'`;
FAIL=0;

echo_log "INFO: running $0 version=$VERSION. Checking user is not root"
# check that we are not launched by root
if [[ $EUID -eq 0 ]]; then
   fail_log "This script $0 must be run as splunk user, not root !" 1>&2
   exit 1
fi

# default


# Note : Important : customer must download ES in order to accept the license
#ESAPP="splunk-enterprise-security_474.spl";
#ESAPP="splunk-enterprise-security_476.spl";
#ESAPP="splunk-enterprise-security_501.spl";
#ESAPP="splunk-enterprise-security_510.spl";
#ESAPP="splunk-enterprise-security_511.spl";
#ESAPP="splunk-enterprise-security_520.spl";
#ESAPP="splunk-enterprise-security_522.spl";
#ESAPP="splunk-enterprise-security_530.spl";
#ESAPP="splunk-enterprise-security_531.spl";
#ESAPP="splunk-enterprise-security_60.spl";
#ESAPP="splunk-enterprise-security_601.spl";
#ESAPP="splunk-enterprise-security_602.spl";
# 6.x , There were potential perf issues with assets and identities in some conditions. please prefer 6.02+ (over 60 and 601) or 6.1.1+(over 610) , please check by your usual source about ES versions and core field status as this comment may be outdated at the time you read it
# (look at least on splservices ES status page for PS + ES RN,...)
#ESAPP="splunk-enterprise-security_61.spl";
#ESAPP="splunk-enterprise-security_611.spl";
#ESAPP="splunk-enterprise-security_620.spl";
#ESAPP="splunk-enterprise-security_640.spl";
#ESAPP="splunk-enterprise-security_641.spl";
#ESAPP="splunk-enterprise-security_660.spl";
#ESAPP="splunk-enterprise-security_662.spl";
#ESAPP="splunk-enterprise-security_700.spl";
#ESAPP="splunk-enterprise-security_701.spl";
#ESAPP="splunk-enterprise-security_702.spl";
#ESAPP="splunk-enterprise-security_710.spl";
#ESAPP="splunk-enterprise-security_711.spl";
#ESAPP="splunk-enterprise-security_720.spl";
#ESAPP="splunk-enterprise-security_730.spl";
#ESAPP="splunk-enterprise-security_731.spl";
#ESAPP="splunk-enterprise-security_732.spl";
#ESAPP="splunk-enterprise-security_802.spl";
#ESAPP="splunk-enterprise-security_810.spl";
#ESAPP="splunk-enterprise-security_811.spl";
ESAPP="splunk-enterprise-security_823.spl";


# SHA256 checksum (splunk-enterprise-security_500.spl) b2a5e4f8297554f4e1818f749386480cfce148e87be8920df939a4282223222c
# SHA256 checksum (splunk-enterprise-security_520.spl) 637881cfeb14866ff11b62b081ff931d32c8931dd200d2fefc9b07898ab42e0b
# SHA256 checksum (splunk-enterprise-security_522.spl) 944eeb780f9ae5414d6e9503a8a6994619a879b58bfe2f7afd7ee7ea2cf3099c
# SHA256 checksum (splunk-enterprise-security_530.spl) 3790e3aa5ec02579c0aaa6ce3e16c19a9ebaa5e1eb2d9bbb5ed8fd2dfdedbf96
# SHA256 checksum (splunk-enterprise-security_531.spl) 2ed1ec05066b7c6492c701de93955a94bae88b793d5ededca27310082083fd24
# SHA256 checksum (splunk-enterprise-security_60.spl) e712bdcda5098b62de59c7b3ed038422f62f160693c96d5a5914366a7c78c525
# SHA256 checksum (splunk-enterprise-security_601.tgz) 6593aa25371f2b960beb9ea6830222e3ebe582c2d750c0709909d776383ec1a1
# SHA256 checksum (splunk-enterprise-security_602.spl) f2920d72d25926474d44bdcbd3eb04c1f968d55e09de33b1bfc97dafeee97a3f
# SHA256 checksum (splunk-enterprise-security_610.spl) f36d5c7fdda4d7ebbb7271f1d849565f58b0dfe6e25f304439ec67978f8298ab
# SHA256 checksum (splunk-enterprise-security_611.spl) 0dc6dc6e275c958cd336ac962dd0fe223d18e4f95b03d636728e417b406c5979
# SHA256 checksum (splunk-enterprise-security_620.spl) dff6806efdbe41141ae8a6b91c1f991d718ce10d8528640b173ea918b8233cd9
# SHA256 checksum (splunk-enterprise-security_640.spl) cbed83ced2af436ded61f000fe87b820c9329148ed612cf2e4374a033eb854a1
# SHA256 checksum (splunk-enterprise-security_640.spl) 940d83e15d4059b09f6a5518bbdc62ce32b6680f4c076a1d46e64cd0c54723c8
# SHA256 checksum (splunk-enterprise-security_641.spl) f44dbc248cb85e8100f7afefe70d7949efab873269657d77e6488ba95c0df077
# SHA256 checksum (splunk-enterprise-security_660.spl) 0e2b72f1396a82a155851b414401740179d955381498ec0d90a6dde70db2479f
# SHA256 checksum (splunk-enterprise-security_662.spl) 2928d7f39b97c61a2d97306c083b1e04eb455df3a5070d9553f6679aacf2fdb4
# SHA256 checksum (splunk-enterprise-security_700.spl) fc83e107f709df2cf4bbebedb5e044b859c5f07ce8a6e21fafcab44bebf60ef4
# SHA256 checksum (splunk-enterprise-security_701.spl) cf3d4afc06bd20f5ab039c01a533b1f5c29c6fbe3dc9dbcf5ef177ef66f36cac
# SHA256 checksum (splunk-enterprise-security_702.spl) 44cd5e63dfdef0e945aa5cf9cd919b50644dc3dee6faaf6d5b29a8c3e4e732ed
# SHA256 checksum (splunk-enterprise-security_710.spl) a45bc6a1a583426e8f587bc0693dbf0296fa61ca2cd9d927e1cf99cab9c351cd
# SHA256 checksum (splunk-enterprise-security_711.spl) b871297c0a518f7362a8a0b6cf829fcefc4bdd24602d0b75d79bb1bc38050e1d
# SHA256 checksum (splunk-enterprise-security_720.spl) a0782af46e32e329bf4eaaf6996476a302a480e20d76255410f6970ce5f5687b
# SHA256 checksum (splunk-enterprise-security_730.spl) 568f72730d61159175495bec665fb2ae2282b760aa9698b52b1682e2acf925dc
# SHA256 checksum (splunk-enterprise-security_731.spl) 1ec5e756206eae020135d52bba4e716a9afc0353a3d2793f25bd351117070102
# SHA256 checksum (splunk-enterprise-security_732.spl) 37581ae057a26f9c7eac04e16f46c11ed8d7bf194491857ff478d874e6f8d1aa
# SHA256 checksum (splunk-enterprise-security_802.spl) 4f996b12b7ff9ed8d27aebb8b0646864e06bca869b3e04472ff9a91dddeab5fe
# sha256 -c 37083026a3f59a9eff5c593dab9b4e111e173d3afab8919a61713c9d4c60c501 splunk-enterprise-security_810.spl
# sha256 -c 8c8e4151535d1d53e8c6f9fc50d6779b26a85924acc93cde85c494945dc39c5c 'splunk-enterprise-security_811.spl
# sha256 -c 572489a9be71a422a274d1c8bced56ef63bff263334bab29c4a8a55f30c0b5d0 'splunk-enterprise-security_823.spl'

# SHA256 checksum (splunk-es-content-update_3240.tgz) 49aca3ab3bb1291f988459708e9a589aacc5b64caed493831a00546c36181ea6

EXPECTEDSHA="572489a9be71a422a274d1c8bced56ef63bff263334bab29c4a8a55f30c0b5d08"


CONTENTUPDATE=`LANG=C;find ${INSTALLAPPDIR}  -name  "splunk-es-content-update_*.tgz" | sort | tail -1`


NBARG=$#
ARG1=$1
ARG2=$2
USEESAPPBYARG=0

if [ $NBARG -eq 0 ]; then
  echo "no arg, using default"
elif [ $NBARG -eq 1 ]; then
  ESAPP=$ARG1
  USEESAPPBYARG=1
elif [ $NBARG -eq 2 ]; then
  ESAPP=$ARG1
  USEESAPPBYARG=1
  ESCU=$ARG2
  CONTENTUPDATE=$ESCU
else
#elif [ $NBARG -gt 1 ]; then
  echo "ERROR: Your command line contains too many ($#) arguments. Ignoring the extra data"
  ESAPP=$ARG1
  USEESAPPBYARG=1
  ESCU=$ARG2
  CONTENTUPDATE=$ESCU
fi
echo "INFO: running $0 version=$VERSION with ESAPP=$ESAPP and ESCU=$ESCU (ESCU is optional)"



echo_log "Note : Please make sure you have read docs, PS ES deployment guide and have been ES implementation trained before running this script"
echo_log "this script install/update ES with content update on a single SH (for SHC, this need to be run on the staging server, not 1 of the SH member !)"
echo_log "in order to use this script you will need : "
echo_log "  - a splunk login password that can install ES (ie admin role)"
echo_log "  - splunk home directory"
echo_log "  - download ES + ES content update from splunkbase, accept license and upload the file locally (default : /opt/splunk/splunkapps)"
echo_log "you should have setup splunk correctly before deploying ES (including tuning for ES, data onboarding with CIM add ons,..) "
echo_log "Note : for upgrade, ES will probably refuse to upgrade if you initially deployed with addons enabled and now managed them via DS (fix this before runnimg the script if needed) "
echo_log "This script is expecting that splunk can be restarted via splunk restart from splunk. If systemd, that probably means, you need to have working polikit configuration"
echo_log "From https://docs.splunk.com/Documentation/ES/latest/Install/InstallEnterpriseSecurity : A new install_apps capability was introduced in Splunk Enterprise v8. The change impacts the existing Enterprise Security edit_local_apps capability's functionality to install and upgrade apps. In ES, enable_install_apps is false by default. If you set enable_install_apps=True and you don't have the new install_apps and existing edit_local_apps capabilities, you will not be able to install and setup apps. This includes performing ES setup and installing other content packs or Technology Add-ons." 

SPLUNK_HOME="/opt/splunk";

read -p "SPLUNK_HOME (default : ${SPLUNK_HOME})" input
SPLUNK_HOME=${input:-$SPLUNK_HOME}

echo_log "INFO: SPLUNK_HOME=${SPLUNK_HOME}"

if [ ! -d "$SPLUNK_HOME" ]; then
  fail_log "SPLUNK_HOME  (${SPLUNK_HOME}) does not exist ! Please check and correct.";
  exit 1;
fi

splunkdtimeout=`${SPLUNK_HOME}/bin/splunk btool web  list  settings | grep splunkdConnectionTimeout | cut -d " " -f 3`
echo_log "splunkdConnectionTimeout=$splunkdtimeout (web.conf in [settings])"
if [ ${splunkdtimeout} -eq 30 ]; then
  warn_log "SplunkdConnectiontimeout is the default splunk value, this could be low for ES setup (and other usages), consider increase it to at least 300s (min 120s) in org_all_search_base or equivalent"
  ((FAIL++))
elif (( ${splunkdtimeout} < 120 )); then
  warn_log "Splunkdtimeout is under 120s, this is very low for ES setup (and other usages), consider increase it to at least 300s in org_all_search_base or equivalent"
  ((FAIL++))
elif (( ${splunkdtimeout} < 300 )); then
  warn_log "Splunkdtimeout is under 300s, this could be low for ES setup (and other usages), consider increase it to at least 300s in org_all_search_base or equivalent"
else 
  echo_log "OK: Splunkdtimeout is >= 300s"
fi

version=`${SPLUNK_HOME}/bin/splunk version | cut -d ' ' -f 2`;
echo_log "Splunk version $version"
if [[ $version =~ ^([^.]+\.[^.]+)\. ]]; then
  ver=${BASH_REMATCH[1]}
  debug_log "current major version is=$ver"
else
  fail_log "splunk version : unable to parse string $version"
  ((FAIL++))
fi
minimalversion=7.3
MESSVER="currentversion=$ver, minimalversionover=${minimalversion}";
# bc not present on some os changing if (( $(echo "$ver >= $minimalversion" |bc -l) )); then
if [ $ver \> $minimalversion ]; then
  CHECKLEVEL=8
else
  CHECKLEVEL=7
fi
debug_log "check_level=${CHECKLEVEL}"

if [ ${CHECKLEVEL} -ne 7 ]; then
  maxuploadsize=`${SPLUNK_HOME}/bin/splunk btool web  list  settings | grep max_upload_size | cut -d " " -f 3`
  echo_log "INFO: (web.conf in [settings]) max_upload_size=${maxuploadsize} "
  # workaroud the fact that btool wont return a value for that param when not custonize (if the defautlt were to be changed, the test will have to be changed)
  if [ -z ${maxuploadsize} ]; then
    fail_log "max_upload_size is unchanged from default which is too low for ES installation to be succesfull. Please fix in org_all_search_base/local/web.conf under settings stanza (or the appropriate app for ES SH custom settings in your env and relaunch installes script"
    ((FAIL++))
    #exit 1
  elif [ ${maxuploadsize} -lt 2048 ]; then
    fail_log "max_upload_size is set but under the required value of 2048. ES app installation require this to be succesfull. Please fix in org_all_search_base/local/web.conf under settings stanza (or the appropriate app for ES SH custom settings in your env and relaunch installes script"
    ((FAIL++))
    #exit 1
  else
    echo_log "OK: max_upload_size is over 1024, fine"
  fi
else
  debug_log "max_upload_size not checked because not yet at v8+"
fi

# folder will always contain README
if [[ $(/usr/bin/find ${SPLUNK_HOME}/etc/shcluster/apps |wc -l) >2 ]]; then
   SHC=1
   echo "looks like we may be running on a SHC deployer, shc install mode prefered for ES5.3+ "
else
   SHC=0
   echo "deployer not detected. Using default sh mode"
fi

read -p "Please verify and confirm SHC mode (0=search_head, 1=shc_deployer) : ${SHC})" input
SHC=${input:-$SHC}

#if [[ "${SHC}" -eq 1 ]]; then
#  INSTALL_MODE="--deployment_type shc_deployer" 
#else
#  # default is search_head but better not set the option so that it can work with pre 5.3 version also
#  INSTALL_MODE="" 
#fi

#INSTALLAPPDIR="/opt/splunk/splunkapps"
INSTALLAPPDIR="${SPLUNK_HOME}/splunkapps"

read -p "INSTALLAPPDIR (default : ${INSTALLAPPDIR})" input
INSTALLAPPDIR=${input:-$INSTALLAPPDIR}
echo_log "INFO: INSTALLAPPDIR=${INSTALLAPPDIR}"
if [ ! -d "$INSTALLAPPDIR" ]; then
  fail_log "INSTALLAPPDIR  (${INSTALLAPPDIR}) does not exist ! Please check and correct.";
  ((FAIL++))
  #exit 1;
fi



read -p "ESAPP file name (default : ${ESAPP})" input
ESAPP=${input:-$ESAPP}
echo_log "ESAPP=${ESAPP}"

ESAPPFULL="${INSTALLAPPDIR}/${ESAPP}"
echo_log "ESAPPFULL=${ESAPPFULL}"

if [ ! -f "$ESAPPFULL" ]; then
  fail_log "ESAPPFULL  (${ESAPPFULL}) does not exist (or permission pb)  ! Please check and correct.";
  ((FAIL++))
  #exit 1;
fi

echo_log "please verify sha256 to check for integrity (corruption , truncation during file download....)"
echo "INFO: expected sha256=${EXPECTEDSHA}"

APP=${ESAPPFULL}
if command -v sha256 &> /dev/null
then
  SHARES=`sha256 ${APP}` 
elif command -v sha256sum &> /dev/null
then
  SHARES=`sha256sum ${APP}` 
fi
if [ -z ${SHARES+x} ]; then
  fail_log "ooops, sha256 could not be calculated, may you need to install the required binary to compute sha256 on your system"
  ((FAIL++))
  #exit 1
else
  SHAb=`echo ${SHARES} |  cut -d " " -f 1`
  debug_log "EXP=${EXPECTEDSHA}"
  debug_log "GOT=${SHAb}"
  if [ "${EXPECTEDSHA}" = "${SHAb}" ]; then
    echo_log "OK: SHA256 verified successfully for Splunk ES installation files ${ESAPPFULL} ${SHAb}"
  elif [ ${USEESAPPBYARG} -eq 1 ]; then
    echo_log "OK: file  ${ESAPPFULL} SHA256=${SHAb} custom app provided cant check"
  else
    fail_log "ERROR: SHA256 doesnt match for ${ESAPPFULL}. possible binary corruption (or you changed binary and it doesn't match expected hash), please investigate why the check failed. EXP=${EXPECTEDSHA},GOT=${SHAb} "
    ((FAIL++))
    #exit 1
  fi
fi


# content update
# example : splunk-es-content-update_1034.tgz
# whether to install/upgrade ES Content update
INSTALLCONTENTUPDATE=1

#read -p "Content update file name (default : ${CONTENTUPDATE})" input
#CONTENTUPDATE=${input:-$CONTENTUPDATE}
if [ -z ${CONTENTUPDATE} ]; then
  warn_log "Couldnt find content update file in ${INSTALLAPPDIR}. disabling ES Content update installation, you can deploy it afterwards (make sure you update it if you have a too old version)"
  INSTALLCONTENTUPDATE=0
  #fail_log "Couldnt find content update file in ${INSTALLAPPDIR}. Please download latest ES content update from Splunkbase and place it here with read write for splunk user them relaunch installation scriot"
  #exit 1
else
  echo_log "OK: CONTENTUPDATE=${CONTENTUPDATE}"
  APP=${CONTENTUPDATE}
  if command -v sha256 &> /dev/null
  then
    SHARES=`sha256 ${APP}`      
  elif command -v sha256sum &> /dev/null
  then
    SHARES=`sha256sum ${APP}`      
  fi
  if [ -z ${SHARES+x} ]; then
    fail_log "ooops, sha256 could not be calculated, may you need to install the required binary to compute sha256 on your system"
    exit 1
  else
    SHAb=`echo ${SHARES} |  cut -d " " -f 1`
    # ES Content update is changing often, we will give info to user that should check the expected value is the one he got when downloading
    #echo_log "EXP :${EXPECTEDSHA}"
    echo_log "GOT :${SHAb}"
    echo_log "Please verify this is matching the sha256 you got from Splunkbase for this version of ES Content update"
    #if [ "${EXPECTEDSHA}" = "${SHAb}" ]; then
    #  echo_log "SHA256 verified successfully for Splunk ES Content update files ${CONTENTUPDATE}"
    #else
    #  fail_log "SHA256 doesnt match for ${CONTENTUPDATE}. Stopping installation here, please investigate why the check failed"
    #  exit 1
    #fi
  fi
fi

LOGGEDIN=0;
# trying to disable bracketed paste mode so password are not escaped when pasted in 
set enable-bracketed-paste off
until [[ "$LOGGEDIN" -eq "1" ]] ; do
# commented out , need to debug it
# the next splunk command will ask for login, just make sur you type the right password each time !
   echo "login with admin credentials"
   set enable-bracketed-paste off
   read -p "enter admin user (default : admin)" input
   SPLADMIN=${input:-admin}
   echo_log "SPLADMIN=${SPLADMIN}"
#
   echo -n "enter admin password and press enter" 
   set enable-bracketed-paste off
   read -s input
   #read -p "enter admin password and press enter" input
   SPLPASS=${input}
#
   ${SPLUNK_HOME}/bin/splunk login -auth $SPLADMIN:$SPLPASS && LOGGEDIN=1;
#
done

echo_log ""
echo_log "OK: logged in"

if [ ${CHECKLEVEL} -ne 7 ]; then
  echo_log "INFO: Checking user capability to install app ?(8.0+)"
  A=`curl -k -X POST -s  -u ${SPLADMIN}:"${SPLPASS}" https://127.0.0.1:8089/services/search/jobs -d search="rest /services/authentication/users/  | search title="${SPLADMIN}"| fields capabilities | eval isok=mvfilter(match(capabilities,\"^edit_local_apps$\")) | search isok=*" -d output_mode=xml -d exec_mode=oneshot -d latest_time=@m`;
  if echo $A | grep "<value h='1'><text>edit_local_apps</text></value>">/dev/null; then
    echo_log "OK: user ${SPLADMIN} have edit_local_apps capability"
  else
    fail_log "ATTENTION !!!!! user ${SPLADMIN} is lacking edit_local_apps capability. Please add this capability to this user as required by ES installation document. Stopping installation"
    ((FAIL++))
    #exit 1;
  fi
else
  debug_log "user capability check not done as not yet v8+"
fi

PROCEEDSKIPINSTALL="N"
read -p "Do you want to skip installation and only do setup (Y/N) ( default = ${PROCEEDSKIPINSTALL})? " input
PROCEEDSKIPINSTALL=${input:-$PROCEEDSKIPINSTALL}
if [ $PROCEEDSKIPINSTALL == "Y" ] || [ $PROCEEDSKIPINSTALL == "y" ] || [ $PROCEEDSKIPINSTALL == "YES" ] || [ $PROCEEDSKIPINSTALL == "yes" ]; then
  echo_log "user want to skip installation"
  PROCEEDSKIPINSTALL="Y"
else 
  debug_log "user want to skip installation"
  PROCEEDSKIPINSTALL="N"
fi

if [ $FAIL -gt 0 ]; then
  fail_log "There were ${FAIL} fail condition(s) detected, please review messages, fix and rerun script before proceeding to installation steps. If you are really sure, you may still try the installation !" 
  PROCEED="N"
  #exit 1
else
  echo_log "OK: looks good, continuing to installation steps"
  PROCEED="Y"
fi

read -p "Do you want to proceed with installation now (Y/N) (check fail number = ${FAIL}, default = ${PROCEED})? " input
PROCEED=${input:-$PROCEED}
if [ $PROCEED == "Y" ] || [ $PROCEED == "y" ] || [ $PROCEED == "YES" ] || [ $PROCEED == "yes" ]; then
  debug_log "user confirmed to proceed to installation"
else 
  echo_log "stopping installation per user input"
  if [ $FAIL -gt 0 ]; then
    # return error
    exit 1
  else
    exit 0
  fi
fi


################################ START INSTALL HERE #########################################
if [ "${PROCEEDSKIPINSTALL}"  == "N" ]; then
  echo_log "INFO: installing/updating ES app from ${ESAPPFULL} with splunk install located in ${SPLUNK_HOME}"

  # timeout not supported here
  # ES install/upgrade
  ${SPLUNK_HOME}/bin/splunk install app ${ESAPPFULL} -update true 

  if [ "${ENABLEWORKAROUNDOUTPUTRELOAD}"  == "yes" ] || [ "${ENABLEWORKAROUNDOUTPUTRELOAD}"  == "YES" ] || [ "${ENABLEWORKAROUNDOUTPUTRELOAD}"  == "Y" ] || [ "${ENABLEWORKAROUNDOUTPUTRELOAD}"  == "y" ]; then
    echo "enabling workaround for spl output reload issue" 
    A=`find /opt/splunk/etc/apps/SplunkEnterpriseSecuritySuite/install -name "Splunk_TA_ueba*spl" -print`
    #Splunk_TA_ueba-3.2.0-73256.spl
    echo "repackaging to add simple outputs reload in $A"
    ls -l $A
    tar -C "/tmp" -xf $A
    cat << EOT >> /tmp/Splunk_TA_ueba/default/app.conf
[triggers]
reload.outputs = simple
EOT

    tar -C"/tmp" -zcf $A Splunk_TA_ueba
    ls -l $A
  else
    echo "disabing workaround for spl output reload issue" 
  fi

  # ${SPLUNK_HOME}/bin/splunk install app ${ESAPPFULL} -update true -auth admin:${PASSWORD}
  #App 'xxxxxx/yyyyyy/splunk-enterprise-security_472.spl' installed 
  #You need to restart the Splunk Server (splunkd) for your changes to take effect.

  # ES Content update
  if [[  "${INSTALLCONTENTUPDATE}" -eq 1 ]]; then
    if [[ "${SHC}" -eq 0 ]]; then
      echo_log "INFO: installing/updating ES content update app from ${CONTENTUPDATE} with splunk install located in ${SPLUNK_HOME} "
      ${SPLUNK_HOME}/bin/splunk install app ${CONTENTUPDATE} -update true 
    else 
      echo "INFO: deployer mode, extracting ES Content Update app to shcluster app instead"
      tar -C"${SPLUNK_HOME}/etc/shcluster/apps/" -zxvf ${CONTENTUPDATE} 
    fi
  fi

  if [[ $INSTALLWITHSETUP = "yes" ]]; then 
    echo_log "INFO: install with setup option set, continuing with setup after install."
    sleep 5
  else
    echo_log "OK: ES installation done. Restarting splunk in 5s"
    sleep 5

    echo_log "INFO: restarting splunk (ignore warning there, we haven't yet done ES setup)"
    echo_log "INFO: if you get prompted here by systemctl, you havent configured polkit properly , please fix this before running this script"
    ${SPLUNK_HOME}/bin/splunk restart 
 
    echo_log "INFO: waiting 5s after restart"
    sleep 5 
  fi
else
  echo_log "installation steps skipped at user request"
fi

${SPLUNK_HOME}/bin/splunk login -auth $SPLADMIN:$SPLPASS

# debug flags in case TCPOutloop crash with 8.2.x

#${SPLUNK_HOME}/bin/splunk set log-level TcpOutputQChannels -level DEBUG
#${SPLUNK_HOME}/bin/splunk set log-level TcpOutputProc -level DEBUG

# note : starting with ES 5.3 , TA are not deployed by default but we already force to disable them 
# starting with ES 6.2 , the exclude TA option no longer exist (the TA ae no longer shipped)

if [[ "${ESINSTALLERNFORCENOTA}" == "yes" ]]; then
  echo_log "INFO: running ES setup with TA excluded (please wait for setup to complete...it will take a while, if you want to follow what ES setup does, you may run in another session tail -f $SPLUNK_HOME/var/log/splunk/essinstaller2.log)"
  if [[ "${SHC}" -eq 1 ]]; then
	${SPLUNK_HOME}/bin/splunk search '| essinstall --deployment_type shc_deployer --skip-ta Splunk_TA_bluecoat-proxysg Splunk_TA_bro Splunk_TA_flowfix Splunk_TA_juniper Splunk_TA_mcafee Splunk_TA_nessus Splunk_TA_nix Splunk_TA_oracle Splunk_TA_ossec Splunk_TA_rsa-securid Splunk_TA_sophos Splunk_TA_sourcefire Splunk_TA_symantec-ep Splunk_TA_ueba Splunk_TA_websense-cg Splunk_TA_windows TA-airdefense TA-alcatel TA-cef TA-fortinet TA-ftp TA-nmap TA-tippingpoint TA-trendmicro ' -timeout 600 
  else
  #  # default is search_head but better not set the option so that it can work with pre 5.3 version also
    ${SPLUNK_HOME}/bin/splunk search '| essinstall --skip-ta Splunk_TA_bluecoat-proxysg Splunk_TA_bro Splunk_TA_flowfix Splunk_TA_juniper Splunk_TA_mcafee Splunk_TA_nessus Splunk_TA_nix Splunk_TA_oracle Splunk_TA_ossec Splunk_TA_rsa-securid Splunk_TA_sophos Splunk_TA_sourcefire Splunk_TA_symantec-ep Splunk_TA_ueba Splunk_TA_websense-cg Splunk_TA_windows TA-airdefense TA-alcatel TA-cef TA-fortinet TA-ftp TA-nmap TA-tippingpoint TA-trendmicro ' -timeout 600 
  fi
else
  echo_log "INFO: running ES setup (please wait for setup to complete...)"
  if [[ "${SHC}" -eq 1 ]]; then
	${SPLUNK_HOME}/bin/splunk search '| essinstall --deployment_type shc_deployer ' -timeout 600 
  else
  #  # default is search_head but better not set the option so that it can work with pre 5.3 version also
    ${SPLUNK_HOME}/bin/splunk search '| essinstall ' -timeout 600 
  fi
fi # no ta

# note : this may timeout in some cases here if you haven't pushed the org_search_base app that increase splunkdtimeout for ES (or any other way of increasing this setting)

#                     INFO
#----------------------------------------------
#Initialization complete, please restart Splunk

echo_log "INFO: end of setup. waiting 5s before restarting"
sleep 5

echo_log "INFO: restarting Splunk after ES setup done"

${SPLUNK_HOME}/bin/splunk restart

# back to INFO

#${SPLUNK_HOME}/bin/splunk set log-level TcpOutputQChannels -level INFO
#${SPLUNK_HOME}/bin/splunk set log-level TcpOutputProc -level INFO

echo_log "ES installed and setup run. Please check for errors in $SPLUNK_HOME/var/log/splunk/essinstaller2.log"
# Marquis check
# INFO STAGE COMPLETE: "finalize"
# 2020-06-08 20:12:46,423+0000 INFO pid=29627 tid=MainThread file=essinstaller2.py:wrapper:82 | STAGE COMPLETE: "finalize"
# 2020-06-08 20:12:46,424+0000 INFO pid=29627 tid=MainThread file=essinstall.py:do_install:265 | Initialization complete, please restart Splunk
if tail -5 "$SPLUNK_HOME/var/log/splunk/essinstaller2.log" | grep -q " STAGE COMPLETE: \"finalize\"";  then
  echo_log "OK: STAGE complete finalize FOUND in $SPLUNK_HOME/var/log/splunk/essinstaller2.log. That is a good sign the install/upgrade went fine" 
  echo_log "ES Setup completed succesfully"
  echo_log "Please login to web interface and verify that no errors are present"
  echo_log "This script has just done the initial ES setup, please continue with the rest of the ES installation guide steps as needed"
  echo_log "in particular, don't forget to : install/upgrade TA (forSH/, configure indexes for ES in org_all_indexes or org_es_indexes via CM for the version of ES used, tune the SH with appropriate scheduling and tuning for ES, tune indexers , ...."
else
  tail -25 $SPLUNK_HOME/var/log/splunk/essinstaller2.log; fail_log "FAIL FAIL FAIL ********************: missing STAGE COMPLETE in $SPLUNK_HOME/var/log/splunk/essinstaller2.log : investigate please ************\nsee above last 25 lines of $SPLUNK_HOME/var/log/splunk/essinstaller2.log "
  echo_log "looking for recent crash log files that could have happened during setup"
  find $SPLUNK_HOME/var/log/splunk -name "crash*" -mmin -5 -print
fi

#echo "INFO: Restarting "
#${SPLUNK_HOME}/bin/splunk restart

# try to fix terminal if ever it went wrong 
stty sane

