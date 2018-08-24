#!/bin/bash
# Absolute path to this script, e.g. /home/user/bin/foo.sh
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in, thus /home/user/bin
SCRIPTPATH=$(dirname "$SCRIPT")
source ${SCRIPTPATH}/envsetup.sh

myprog=$(basename $0)

function absolutepath()
{
  echo -n "$(cd -P -- "$(dirname -- "$1")" && pwd -P)"
}


if [ $# -lt 1 ]; then
    echo "./$myprog <PROJECT> [ROLLBACK_VERSION] [MODULE NAME] [FILE PATH]"
    echo "For example ./$myprog Mickey6TTFEVDO"
    exit 254
fi

# $1: project name
# $2: anti-rollback version
# $3: image type
# $4: image path

EXPECTED_PROJECT_PATH=$(mktemp -u -d --tmpdir packboot-XXXXXX)
EXPECTED_SIGN_PATH=${SCRIPTPATH}
TCL_TOPFILE=build/core/envsetup.mk
the_time_for_try=15

PROJECT_NAME=$1
if [ -n "$(echo $2| sed -n "/^[0-9]\+$/p")" ];then 
  echo "Use the input version number:$2  as anti-rallback-version."
  TARGET_ROLLBACK_VERSION=$2
  IMAGE_NAME=$3
  IMAGE_PATH=$4
else 
  echo "Use the default anti-rollback version."
  TARGET_ROLLBACK_VERSION=0
  IMAGE_NAME=$2
  IMAGE_PATH=$3
fi 

projectlen=`expr length $PROJECT_NAME`
if test $projectlen -gt 20; then #Max project name length is 20
  echo "Project name $PROJECT_NAME length $projectlen is too long!"
  exit
fi

echo "=======PROJECT_LEN:$projectlen,PROJECT:$PROJECT_NAME,MODULE NAME:$IMAGE_NAME,FILE PATH:$IMAGE_PATH,TARGET_ROLLBACK_VERSION:$TARGET_ROLLBACK_VERSION======"

target_dir=out/target/product/$1/
mkdir -p $EXPECTED_PROJECT_PATH/$target_dir

function filterOutNotExist()
{

  sed -e  "s:tar2img/Mickey6TTFEVDO.tar.gz:tar2img/${PROJECT_NAME}.tar.gz:" \
      -e  "s:product/Mickey6TTFEVDO:product/${PROJECT_NAME}:" \
      -e "s/\=\"Mickey6TTFEVDO\"/=\"$PROJECT_NAME#$TARGET_ROLLBACK_VERSION\"/" CSCconfig-readonly.xml > ${1}
    local T=$(gettop)
    local input
    local rsignid=(`awk 'BEGIN {i=0};$2 ~ /path/ { split($1,a,/</);vars[i++]=a[2]}; END {for(j = 0; j <i ;j++) print vars[j]}' \
        ${1}`)
    local patharr=(`eval echo $(awk   'BEGIN {i=0};$2 ~ /path/ { split($2,a,/[="]+/);vars[i++]=a[2]}; END {for(j = 0; j <i ;j++) print vars[j]}'  ${1})`)
    #echo xx${rsignid[@]} pp${patharr[@]}
    i=0
    for id in ${rsignid[@]}
    do
        input=${patharr[$i]}
        eval $id=$input
        let i++
    done
}

function fileExist()
{
    local T=$(gettop)
    local rsignid=(`awk 'BEGIN {i=0};$2 ~ /path/ { split($1,a,/</);vars[i++]=a[2]}; END {for(j = 0; j <i ;j++) print vars[j]}' \
        ${1}`)
    local patharr=(`eval echo $(awk   'BEGIN {i=0};$2 ~ /path/ { split($2,a,/[="]+/);vars[i++]=a[2]}; END {for(j = 0; j <i ;j++) print vars[j]}'  ${1})`)
    #echo xx${rsignid[@]} pp${patharr[@]}
    i=0
    for id in ${rsignid[@]}
    do
        input=${patharr[$i]}
        if [ -e $input ];then
           return 0
        fi
        let i++
    done
    echo "files not exists:${patharr}"
    exit 252
}

function sign_process()
{
  i=0
  while( test $i -lt 3 ) #6
  do
    i=$(($i+1))
    echo Sign count $i
    ${SCRIPTPATH}/SignClient $cfg_magic &
    CHILD_PID=$!
    trap -- 'runcmd kill -9 ${CHILD_PID};exit 253' SIGQUIT SIGKILL SIGINT SIGTERM
    let timer=$1/2 #300 After 10 mins if the client is still running, kill it.
    flag=1 #Mark if the client is exist.
    while [ $timer -gt 0 ]
    do
      sleep 2
      if [ -e "/proc/${CHILD_PID}/exe" ];then
          echo -n -e "signing process wait $((${timer}*2))s for SignClient ${CHILD_PID} exit \r"
          let timer-=1
          continue
      fi
      flag=0 && break #if the client is not exist, exit this loop
    done
    [ $flag -eq 1 ] && kill -9  ${CHILD_PID}
    [ $flag -eq 1 ] && kill -9  ${CHILD_PID}
    wait $CHILD_PID
    CHILD_RET=$?
    echo "SignClient status $CHILD_RET!!!"
        
	if test $CHILD_RET -eq 0 ; then
	  echo "Sign successfully"
	  break
    else
      sleep 5
      if test $i -eq 1; then
        mv $cfg_magic_file "$cfg_magic_file"_retry
        sed "s/servip=\"10.128.180.220\"/servip=\"10.128.180.117\"/" "$cfg_magic_file"_retry > $cfg_magic_file  
        rm "$cfg_magic_file"_retry
		echo "Try other server!!!"
      elif test $i -eq 2; then
        mv $cfg_magic_file "$cfg_magic_file"_retry
        sed "s/servip=\"10.128.180.117\"/servip=\"10.128.180.21\"/" "$cfg_magic_file"_retry > $cfg_magic_file
        rm "$cfg_magic_file"_retry
		echo "Try the third server!!!"
      elif test $i -lt 3; then
        continue
      else
		echo "Sign exception occur"
		exit 255
      fi
    fi
  done
}

function sign_one_image()
{
   #touch $cfg_magic_file
   if [ -n "$IMAGE_PATH" ];then
       echo "==Use the input image path =====$IMAGE_PATH======="
   else
       IMAGE_PATH=${!IMAGE_NAME}
       echo "==Use the default image path=====$IMAGE_PATH======="
   fi
   echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
      <codesign>
        <project name=\"$PROJECT_NAME#$TARGET_ROLLBACK_VERSION\" servip=\"10.128.180.220\" servport=\"18918\">
	      <$IMAGE_NAME path=\"$IMAGE_PATH\" />
	</project>
    </codesign> " > $cfg_magic_file

  fileExist $cfg_magic_file
  if [[ $? -eq 0 ]];then
      sign_process 80
  fi
  rm $cfg_magic_file
}

(
flock -s -n 9
if [ $? -eq 1 ];then
    echo -n "waiting for another process sign:"
    cat $EXPECTED_PROJECT_PATH/signing.lock
fi

cfg_magic_file=$(mktemp CSCconfig-XXXXXXXXX.xml)
cfg_magic_file_bak=${cfg_magic_file}_bak
cfg_magic=${cfg_magic_file#CSCconfig-}
cfg_magic=${cfg_magic%.xml}

trap -- 'runcmd rm -f ${cfg_magic_file} ${cfg_magic_file_bak}'  EXIT

flock 9
echo "Start signing $cfg_magic_file ..."
echo "$0 $1 $2 $3 $4 pid:$$" > $EXPECTED_PROJECT_PATH/signing.lock
#match to end
#cd ${SCRIPTPATH}
filterOutNotExist  $cfg_magic_file
if [ -n "$IMAGE_NAME" ]; then
  echo "Single sign start"
  sign_one_image
  echo "Single sign end" 
else
  echo "multi sign start"
  sed -e  "s/product\/Mickey6TTFEVDO/product\/$PROJECT_NAME/" \
      -e "s/\=\"Mickey6TTFEVDO\"/=\"$PROJECT_NAME#$TARGET_ROLLBACK_VERSION\"/"  CSCconfig-readonly.xml >  $cfg_magic_file

  fileExist $cfg_magic_file
  if [[ $? -eq 0 ]];then
      sign_process 300
  fi
  rm $cfg_magic_file
  echo "multi sign end"
fi

echo Sign done at `date`!!!
#cd $OLDPWD
) 9>>$EXPECTED_PROJECT_PATH/signing.lock
#match to start
