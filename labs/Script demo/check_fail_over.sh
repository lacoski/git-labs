#!/bin/bash
### Server Active check
WEBSERVER_CHECK=10.200.200.135 #master #truong xet 1 file main config
STATUS_CODE=`curl -sL -w "%{http_code}\\n" "$WEBSERVER_CHECK" -o /dev/null`
TIME=`date`
LOG=/var/log/script-gitlabs/slave.log
MESSAGE_LOG=""
STATE_RSYNC=`ps -ef | grep -v grep | grep 'rsync ' | wc -l`
STATE_MASTER=0 # 0 = fail; 1 = true; 2 = error
STATE_SERVICE=0 # 0 = fail; 1 = true;

### Function LOG
logger_func () {
  if [ ! -d /var/log/script-gitlabs/ ]; then
        mkdir -p /var/log/script-gitlabs/
  fi
  echo "$TIME: $1" >> $LOG
}
### Start Check
Message="Start process check fail over active-passive !!!!"
echo $Message
logger_func "$Message"
### Check web service
if (( $STATE_RSYNC == "0" ))
then
    echo "rsyncd not on"
fi
### Check web service
if [ $STATUS_CODE != 000 ]
then
  if [ $STATUS_CODE == 200 ]
  then
    #echo "Check service Active Gitlab On!!"
    STATE_MASTER=1
  else #Error service on gitlab Active
    #echo "Check status code Fail! - status code = $STATUS_CODE "
    STATE_MASTER=2
  fi
else
  # echo "Service gitlab on remote not on"
  STATE_MASTER=0
fi

### Check service
gitlab-ctl status | grep ^run
if [ $? == 0 ]
then
        STATE_SERVICE=1
fi
## Fail over.
if [ $STATE_MASTER == 0 ] || [ $STATE_MASTER == 2 ] && [ $STATE_SERVICE == 0 ]
then
  gitlab-ctl start
  Message="Fail Over true - Start gitlab service on local"
  echo $Message
  logger_func "$Message"
else
  case "$STATE_MASTER" in
    0)  Message="State gitlabs active is off"
    echo $Message
    logger_func "$Message"
        ;;
    1)  Message="State gitlabs active is on"
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
  case "$STATE_SERVICE" in
    0)  Message="Service gitlabs is off"
    echo $Message
    logger_func "$Message"
        ;;
    1)  Message="Service gitlabs is on - Kiem tra dong bo du lieu Master - Slave"
    echo $Message
    logger_func "$Message"
        ;;
    *) Message="Loi kiem tra, check state service gitlab local"
    echo $Message
    logger_func "$Message"
        ;;
  esac
fi
Message="End process check failover active-passive !!!!!"
echo $Message
logger_func "$Message"
