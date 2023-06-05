#!/bin/bash

# Copyright 2023 Splunk Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Contributor :
#
# Matthieu Araman, Splunk
#
# This script is used to package apps based on instance role

# 20230301 initial version
# 20230511 rework to allow only generate instance list needed
# 20230511 add more roles and apps
# 20230513 add org variable
# 20230514 add version var
# 20230514 extend args to make CERTSDIR a arg
# 20230605 add extra package by apps already individually packaged

VERSION="20230605a"

function package() {
  for i in $TARGET
  do 
    echo "Creating dir=${PDIR}/$i if not present"
    /bin/mkdir -v -p ${PDIR}/$i
    echo "looking for candidates for package ${PDIR}/$i/initial${SUFFIX}apps.tar.gz for org=$ORG from files in $APPDIR with these apps template : $APPS"
    APPS2=""
    APPS3=""
    for A in $APPS 
    do
      if [ -d $APPDIR/$A ]; then
        find $APPDIR/$A -name "._*" -delete
        find $APPDIR/$A -name ".DS_*" -delete
        B=${A//org/"$ORG"}
        if [ "$ORG" != "org" ]; then
          cp -rp $APPDIR/$A $APPDIR/$B
        fi
        APPS2="${APPS2} $B"
        APPS3="${APPS3} $APPDIR/$B"
        echo "ORG=$ORG, A=$A, B=$B"
        echo "Packaging app $B in ${PDIR}/$i/$B.tar.gz from files in $APPDIR/$B"
        tar -C "$APPDIR" -zcf "${PDIR}/$i/$B.tar.gz" $APPDIR/$B
      else
        echo "KO : app dir $A does not exist"
      fi
    done
    if [[ $APPS2 ]]; then
      echo "Creating package ${PDIR}/$i/initial${SUFFIX}apps.tar.gz from files in $APPDIR including these apps template : $APPS2"
      tar -C "$APPDIR" -zcf "${PDIR}/$i/initial${SUFFIX}apps.tar.gz" $APPS2
      echo "Creating apps package ${PDIR}/$i/apps${SUFFIX}.tar.gz from files in $APPDIR including these packaged apps  : $APPS3"
      tar -C "$APPDIR" -zcf "${PDIR}/$i/apps${SUFFIX}.tar.gz" $APPS3
    else
      echo "empty app list , not doing tar for ${PDIR}/$i/initial${SUFFIX}apps.tar.gz  "
    fi
    #tar -C "$APPDIR" -zcf "${PDIR}/$i/initial${SUFFIX}apps.tar.gz" $APPS
  done
}

# note : certificates were already generated here
function init_tls() {
  if [[ $ENABLETLS == 1 ]]; then 
    for i in $TARGET
    do 
      echo "Creating ${PDIR}/$i if not present"
      /bin/mkdir -v -p ${PDIR}/$i
      SUFFIX="tls"
      echo "Creating package ${PDIR}/$i/initial${SUFFIX}apps.tar.gz from files in $APPDIR including these directories : $APPS"
      tar -C "$APPDIR" -zcvf "${PDIR}/$i/initial${SUFFIX}apps.tar.gz" $APPS
      if [ -e "${CERTSDIR}/$i/mycerts.tar.gz" ]; then 
        echo "copying certs from ${CERTSDIR}/$i/mycerts.tar.gz to ${PDIR}/$i/"
        cp ${CERTSDIR}/$i/mycerts.tar.gz ${PDIR}/$i/
      else 
        echo "ATTENTION : certs dont exist (${CERTSDIR}/$i/mycerts.tar.gz), this may impact tls deployment, continuing"
      fi
      if [ -e "./local/splunkclouduf.spl" ]; then
        echo "copying splunkclouduf.spl to packaged dir"
        cp -fp ./local/splunkclouduf.spl ${PDIR}/$i/
      else
        echo "splunkclouduf.spl not present. This is safe if you dont send data to splunkcloud "
      fi
    done
  fi
}

if [ $# -lt 6 ]; then
  echo "Please provide org, orig app dir,  target dir for packaged, 0 or 1 for enabletls (apps), certsdir  followed by role list as arguments like $0 org appsdir packagedir enabletls certsdir role1 role2 role3 ..."
  exit 1
fi

ORG=$1
APPDIR=$2
PDIR=$3
ENABLETLS=$4
CERTSDIR=$5
ROL=${@:6}

echo "**************************************************************************************"
echo "ORG=$ORG,APPDIR=${APPDIR},PDIR=${PDIR},ENABLETLS=${ENABLETLS}, CERTSDIR=$CERTSDIR"
echo "INFO:  roles=${ROL}"


echo "current dir is "
pwd

ROLELIST=$ROL

for TARGET in $ROLELIST
do
  echo "processing TARGET=$TARGET"
  if [[ $TARGET == std* ]]; then  
    APPS="org_all_search_base org_all_ui_tls org_all_indexes org_es_indexes org_indexer_volume_indexes org_indexer_s2_indexes"
    SUFFIX=""
    package
    APPS="org_all_tls"
    init_tls
  elif [[ $TARGET == cm* ]]; then  
    APPS="org_all_search_base org_all_ui_tls org_manager_multisite org_search_outputs-disableindexing org_to-site_forwarder_central_outputs org_site_0_base org_manager_deploymentclient org_full_license_peer"
    # lm on cm case
    APPS="org_all_search_base org_all_ui_tls org_manager_multisite org_search_outputs-disableindexing org_to-site_forwarder_central_outputs org_site_0_base org_manager_deploymentclient"
    SUFFIX=""
    #TARGET="cm cm1 cm2 cm3 cm4 cm5"
    package
    APPS="org_all_tls"
    init_tls

    APPS="org_indexer_base org_all_indexes org_es_indexes org_indexer_volume_indexes org_indexer_s2_indexes org_full_license_peer"
    SUFFIX="manager"
    #TARGET="cm cm1 cm2 cm3 cm4 cm5"
    package
  elif [[ $TARGET == ds* ]]; then
    # deploymentserver_base renamed here
    APPS="org_all_search_base org_all_ui_tls org_deploymentserver_base org_search_outputs-disableindexing org_full_license_peer org_to-site_forwarder_central_outputs"
    SUFFIX=""
    #TARGET="ds ds1 ds2 ds3 ds4 ds5"
    package
    APPS="org_all_tls"
    init_tls

    APPS="org_all_search_base org_all_ui_tls org_search_outputs-disableindexing org_full_license_peer org_to-site_forwarder_central_outputs org_indexer_base org_all_indexes org_es_indexes org_indexer_volume_indexes org_indexer_s2_indexes org_search_volume_indexes"
    SUFFIX="ds"
    #TARGET="ds ds1 ds2 ds3 ds4 ds5"
    package
  elif [[ $TARGET == sh* ]]; then
    APPS="org_es_search_base org_all_ui_tls org_search_cluster_peer org_site_0_base org_all_deploymentclient org_search_outputs-disableindexing org_full_license_peer org_to-site_forwarder_central_outputs org_all_indexes org_es_indexes org_search_volume_indexes"
    SUFFIX=""
    #TARGET="sh sh1 sh2 sh3"
    package
    APPS="org_all_tls"
    init_tls
  elif [[ $TARGET == mc* ]]; then
    APPS="org_all_search_base org_all_ui_tls org_search_outputs-disableindexing org_full_license_peer org_to-site_forwarder_central_outputs org_monitoringconsole_search_base"
    SUFFIX=""
    #TARGET="mc mc1 mc2 mc3"
    package
    APPS="org_all_tls"
    init_tls
  elif [[ $TARGET == hf* ]]; then
    APPS="org_hf_base org_all_ui_tls org_search_outputs-disableindexing org_full_license_peer org_to-site_forwarder_central_outputs"
    SUFFIX=""
    #TARGET="hf hf1 hf2 hf3 hf4 hf5"
    package
    APPS="org_all_tls"
    init_tls
  elif [[ $TARGET == "ihf" ]]; then
    APPS="org_all_search_base org_all_ui_tls org_full_license_peer splunk_httpinput 00_org_ia_tuning org_1s2_indexer_indexes splunk_ingest_actions"
    SUFFIX=""
    #TARGET="ihf"
    package
    APPS="org_all_tls"
    init_tls
  elif [[ $TARGET == "ihf2" ]]; then
    APPS="org_all_search_base org_all_ui_tls org_full_license_peer splunk_httpinput 00_org_ia_tuning org_2s2_indexer_indexes splunk_ingest_actions"
    SUFFIX=""
    #TARGET="ihf2"
    package
    APPS="org_all_tls"
    init_tls
  elif [[ $TARGET == "ihf3" ]]; then
    APPS="org_all_search_base org_all_ui_tls org_full_license_peer splunk_httpinput 00_org_ia_tuning org_3s2_indexer_indexes splunk_ingest_actions"
    SUFFIX=""
    #TARGET="ihf3"
    package
    APPS="org_all_tls"
    init_tls
  elif [[ $TARGET == "ihf4" ]]; then
    APPS="org_all_search_base org_all_ui_tls org_full_license_peer splunk_httpinput 00_org_ia_tuning org_4s2_indexer_indexes splunk_ingest_actions"
    SUFFIX=""
    #TARGET="ihf4"
    package
    APPS="org_all_tls"
    init_tls
  elif [[ $TARGET == "ihf5" ]]; then
    APPS="org_all_search_base org_all_ui_tls org_full_license_peer splunk_httpinput 00_org_ia_tuning org_5s2_indexer_indexes splunk_ingest_actions"
    SUFFIX=""
    #TARGET="ihf5"
    package
    APPS="org_all_tls"
    init_tls
  elif [[ $TARGET == idx* ]]; then
    APPS="org_indexer_cluster_base" 
    SUFFIX=""
    #TARGET="idx idx1 idx2 idx3 idx4 idx5"
    package
    APPS="org_all_tls org_indexer_tls"
    init_tls
  elif [[ $TARGET == iuf* ]]; then
    APPS="org_uf_base org_to-site_forwarder_central_outputs"
    SUFFIX=""
    TARGET="iuf uf uf1 uf2 uf3"
    package
    APPS="org_uf_tls"
    init_tls
  fi
done

#aws s3 sync PDIR s3://${s3_install}/packaged
