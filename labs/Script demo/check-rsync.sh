#!/bin/bash
### VAR
WEBSERVER_CHECK=10.200.200.61 #slave
STATUS_CODE=`curl -sL -w "%{http_code}\\n" "$WEBSERVER_CHECK" -o /dev/null`
RSYNC_CHECK=0   # 0 = not sync; 1 = sync; 3 = fail check web service; 4 = fail check service local
TIME=`date`
LOG=/var/log/script-gitlabs/master.log
MESSAGE_LOG=""
STATE_RSYNC=`ps -ef | grep -v grep | grep 'rsync ' | wc -l`
STATE_SLAVE=0 # 0 = fail; 1 = true; 2 = error
STATE_SERVICE=0 # 0 = fail; 1 = true;
STATE_WEB_SERVICE=0 # 0 = fail; 1 = true; 2 = error
CHECK_PROCESS_RSYNC=`ps -ef | grep -v grep | grep 'rsync -azvr --delete /var/opt/gitlab/' | wc -l`
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
### Check web service slave
if [ $STATUS_CODE != 000 ]
then
  if [ $STATUS_CODE == 200 ]
  then
    #echo "Check service Passive Gitlab On!!"
    STATE_SLAVE=1
  else #Error service on gitlab Passive
    #echo "Check status code Fail! - status code = $STATUS_CODE "
    STATE_SLAVE=2
  fi
else
  # echo "Service gitlab on remote not on"
  STATE_SLAVE=0
fi
### Check web service master
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
if [ $STATE_SLAVE == 0 ] && [ $STATE_SERVICE == 1 ] && [ $STATE_WEB_SERVICE == 1 ] && [ $CHECK_PROCESS_RSYNC == 0 ]
then
  RSYNC_CHECK=1
else
  case "$STATE_SLAVE" in
    0)  Message="State gitlabs slave is off"
    echo $Message
    logger_func "$Message"
            ;;
    1)  Message="State gitlabs slave is on - Dong bo nguoc Passive - Master"
    echo $Message
    logger_func "$Message"
        ;;
    2)  Message="State gitlabs slave is error - http_code = $STATUS_CODE"
    echo $Message
    logger_func "$Message"
        ;;
    *) Message="Loi kiem tra, check state service gitlab slave"
    echo $Message
    logger_func "$Message"
        ;;
  esac

  case "$STATE_SERVICE" in
    0)  Message="Service gitlabs is off - Kiem tra dong bo du lieu Master - Slave"
    echo $Message
    logger_func "$Message"
        ;;
    1)  Message="Service gitlabs is on"
    echo $Message
    logger_func "$Message"
    case "$STATE_WEB_SERVICE" in
      0)  Message="Service Gitlab web is off"
      echo $Message
      logger_func "$Message"
          ;;
      1)  Message="Service Gitlab web is on"
      echo $Message
      logger_func "$Message"
          ;;
      2)  Message="Service Gitlab web - http_code = $LOCAL_STATUS_CODE"
      echo $Message
      logger_func "$Message"
          ;;
      *) Message="Loi kiem tra, check state service Gitlab web"
      echo $Message
      logger_func "$Message"
          ;;
    esac
    case "$CHECK_PROCESS_RSYNC" in
      0)  Message="Process rsyncd is not run"
      echo $Message
      logger_func "$Message"
              ;;
      1)  Message="Process rsyncd is running - Cant not rsyncd"
      echo $Message
      logger_func "$Message"
          ;;
      *) Message="Loi kiem tra, check process rsyncd"
      echo $Message
      logger_func "$Message"
          ;;
    esac
        ;;
    *) Message="Loi kiem tra, check state service gitlab local"
    echo $Message
    logger_func "$Message"
        ;;
  esac
fi
## Syn data
if [ $RSYNC_CHECK == 1 ]
then
  rsync -azvr --delete /var/opt/gitlab/ root@$WEBSERVER_CHECK:/var/opt/gitlab/ --log-file=/var/log/script-gitlabs/rsync.log
  Message="Sync to Passive GitLabs - Check state true"
  echo $Message
  logger_func "$Message"
  #echo "$TIME: Sync to Passive GitLabs - Check state true" >> $LOG || echo "Something wrong, check state rsyncd" >> $LOG
else
  Message="Can not sync data active-passive - Check log "
  echo $Message
  logger_func "$Message"
fi
Message="End process sync data active-passive !!!!"
echo $Message
logger_func "$Message"
