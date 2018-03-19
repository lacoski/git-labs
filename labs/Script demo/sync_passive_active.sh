#!/bin/bash
### VAR
WEBSERVER_CHECK=10.200.200.135
STATUS_CODE=`curl -sL -w "%{http_code}\\n" "$WEBSERVER_CHECK" -o /dev/null`
RSYNC_CHECK=0
TIME=`date`
LOG=/var/log/script-gitlabs/sync-passive-active.log
MESSAGE_LOG=""
STATE_RSYNC=`ps -ef | grep -v grep | grep 'rsync ' | wc -l`
STATE_MASTER=0 # 0 = fail; 1 = true; 2 = error
STATE_WEB_SERVICE=0 # 0 = fail; 1 = true; 2 = error
STATE_SERVICE=0 # 0 = fail; 1 = true;
### Function LOG
logger_func () {
  if [ ! -d /var/log/script-gitlabs/ ]; then
        mkdir -p /var/log/script-gitlabs/
  fi
  echo "$TIME: $1" >> $LOG
}
### Start Check
Message="Start process sync data active-passive !!!!"
echo $Message
logger_func "$Message"
### check service rsyncd
if (( $STATE_RSYNC == "0" ))
then
    echo "rsyncd not on"
fi
### Check web service master
if [ $STATUS_CODE != 000 ]
then
  if [ $STATUS_CODE == 200 ]
  then
    #echo "Check service Passive Gitlab On!!"
    STATE_MASTER=1
  else #Error service on gitlab Passive
    #echo "Check status code Fail! - status code = $STATUS_CODE "
    STATE_MASTER=2
  fi
else
  # echo "Service gitlab on remote not on"
  STATE_MASTER=0
fi
### Check web service local
LOCAL_STATUS_CODE=`curl -sL -w "%{http_code}\\n" "127.0.0.1" -o /dev/null`
if [ $LOCAL_STATUS_CODE != 000 ]
then
  if [ $LOCAL_STATUS_CODE == 200 ]
  then
    #echo "Check service Active Gitlab On!!"
    STATE_WEB_SERVICE=1
  else #Error service on gitlab Passive
    #echo "Check status code Fail! - status code = $STATUS_CODE "
    STATE_WEB_SERVICE=2
  fi
else
  # echo "Service gitlab active is off"
  STATE_WEB_SERVICE=0
fi
### Check service gitlab on server
gitlab-ctl status | grep ^run
if [ $? == 0 ]
then
  # echo "Service gitlab On"
  STATE_SERVICE=1
fi
### Condition RSYNC_CHECK
if [ $STATE_MASTER == 0 ] && [ $STATE_SERVICE == 1 ] && [ $STATE_WEB_SERVICE == 1 ]
then
  RSYNC_CHECK=1
else
  case "$STATE_MASTER" in
    0)  Message="State gitlabs active is off"
    echo $Message
    logger_func "$Message"
        ;;
    1)  Message="State gitlabs active is on - Khong the dong bo"
    echo $Message
    logger_func "$Message"
        ;;
    2)  Message="State gitlabs active is error - http_code = $STATUS_CODE"
    echo $Message
    logger_func "$Message"
        ;;
    *) Message="Loi kiem tra, check state service gitlab active"
    echo $Message
    logger_func "$Message"
        ;;
  esac

fi

read -p "Ban co muon dong bo ko (y/n)?" choice
case "$choice" in
  y|Y ) echo "Tiep tuc qua trinh dong bo:.....";;
  n|N ) echo "Thoat tien trinh!"
        RSYNC_CHECK=0
  ;;
  * ) echo "Sai cu phap, thoat tien trinh"
        RSYNC_CHECK=0
  ;;
esac

if [ $RSYNC_CHECK == 1 ]
then

  rsync -azvr --delete /var/opt/gitlab/ root@$WEBSERVER_CHECK:/var/opt/gitlab/ --log-file=/var/log/script-gitlabs/rsync.log
  Message="Sync to active GitLabs - Check state true"
  echo $Message
  logger_func "$Message"
  #echo "$TIME: Sync to Passive GitLabs - Check state true" >> $LOG || echo "Something wrong, check state rsyncd" >> $LOG
else
  Message="Can not sync data passive-active - Check log "
  echo $Message
  logger_func "$Message"
fi
Message="End process sync data passive-active !!!!"
echo $Message
logger_func "$Message"
