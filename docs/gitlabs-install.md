# TRIỂN KHAI GITLAB
---
## Chuẩn bị
### 1. Sơ đồ triển khai
![](../images/gitlab-install-1.png)

### 2. Cấu hình
Node Active
```
CPU: 4 core
RAM: 16GB
HDD: 500GB
Ip tĩnh: 10.200.200.228
```
> Active server chịu trách nhiệm giải quyết request

Node Passive
```
CPU: 4 core
RAM: 16GB
HDD: 500GB
Ip tĩnh: 10.200.200.229
```
> Passive server, chịu lỗi khi Active xảy ra vấn đề

## Cài đặt
__Mục lục__

[Phần 1: Cài đặt Gitlab](#phan1)

[Phần 2: Cấu hình Keep alive](#phan2)

[Phần 3: Cấu hình Rsync](#phan3)

[Phần 4: Cấu hình ssh bỏ qua pass giữa active passive](#phan4)

[Phần 5: Cấu hình đồng bộ, chịu lỗi, HA](#phan5)

[Phần 6: Qui trình khởi động GitLab](#phan6)

<a name="phan1"></a>
### Phần 1: Cài đặt Gitlab
#### Bước 1: Cấu hình firewalld
Trên CentOS, mở port HTTP và SSH vào system firewalld
```
sudo yum install -y curl policycoreutils-python openssh-server
sudo systemctl enable sshd
sudo systemctl start sshd
sudo firewall-cmd --permanent --add-service=http
sudo systemctl reload firewalld
```

#### Bước 2: Cấu hình Postfix
Cài đặt Postfix để gửi thông báo qua Emails. Nếu sử dụng giải pháp khác cho vấn đề gửi Email, bỏ qua bước này.

```
sudo yum install postfix
sudo systemctl enable postfix
sudo systemctl start postfix
```

#### Bước 3: Cài đặt Gitlab
Add gói GitLab repo và cài đặt gói
```
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.rpm.sh | sudo bash
```
Cấu hình URL cho thực thi GitLab
```
sudo EXTERNAL_URL="http://gitlab.local.com" yum install -y gitlab-ee
```

#### Bước 4: Truy cập giao diện chính
Truy cập thông qua URL (Khi setup domain)
```
http://gitlab.local.com
```
Truy cập thông qua IP
```
http://IP
```

> Tại lần đầu tiên truy cập vào GitLab, ta sẽ phải cấu hình user “root” của hệ thống. Đây là user quản trị toàn bộ hệ thống GitLab.

> User: root

> Pass: <set khi truy cập lần đâu>

<a name="phan2"></a>
### Phần 2: Cấu hình Keep alive
> Keepalived là gì : hiểu đơn giản keepalived là phần mền để tạo ra 1 VIP ( Virtual IP - IP ảo ). VIP này đại  diện cho 2 hay nhiều IP thật trên các máy chủ hay các thiết bị. Khi người dùng truy cập vào website hay các ứng dụng sử dụng VIP này. Keepalived sẽ sử dụng các thuật toán để ánh xạ VIP vào những IP thật của các máy chủ, thiết bị

pic![](../images/gitlab-install-1.png)

#### Bước 1: Cài đặt gói keepalived trên Git Active
Cài đặt gói
```
yum -y install keepalived
```
Cấu hình
```
vi /etc/keepalived/keepalived.conf
```
Nội dung
```
vrrp_script check_state {
  script “/etc/gitlab/check_state.sh” # verify the pid existance
  interval 2 # check every 2 seconds
  weight 4 # add 2 points of prio if OK
}
vrrp_instance VI_1 {
  interface ens37 # interface to monitor
  state MASTER
  virtual_router_id 51 # Assign one ID for this route
  priority 101 # 101 on master, 100 on backup

  virtual_ipaddress {
    10.200.200.227 dev ens37 # the virtual IP
  }
  track_script {
    check_state
  }
}
```
__Script check trạng thái service Gitlabs__

```
vi /etc/gitlab/check_state.sh
```
Nội dung
```bash
#!/bin/bash
### Server Active check
WEBSERVER_CHECK=127.0.0.1
STATUS_CODE=`curl -sL -w "%{http_code}\\n" "$WEBSERVER_CHECK" -o /dev/null`

echo $STATUS_CODE

if [ $STATUS_CODE == 200 ]
then
        echo "true"
        exit 0
elif [ $STATUS_CODE == 000 ]
then
        echo "Code fail!!"
        exit 1
else
        echo "not known"
        exit 1
fi

echo "fail all"
exit 1
```
Khởi động service Keep alived
```
systemctl start keepalived
systemctl enable keepalived
systemctl status keepalived
```

#### Bước 2: Cài đặt trên Git Passive
Cài đặt gói
```
yum -y install keepalived
```
Cấu hình
```
vi /etc/keepalived/keepalived.conf
```
Nội dung
```
###
vrrp_script check_state {
  script “/etc/gitlab/check_state.sh” # verify the pid existance
  interval 2 # check every 2 seconds
  weight 2 # add 2 points of prio if OK
}
vrrp_instance VI_1 {
  interface ens37 # interface to monitor
  state MASTER
  virtual_router_id 51 # Assign one ID for this route
  priority 101 # 101 on master, 100 on backup

  virtual_ipaddress {
    10.200.200.227 dev ens37 # the virtual IP
  }
  track_script {
    check_state
  }
}
```
Script check trạng thái service Gitlabs
```
vi /etc/gitlab/check_state.sh
```
Nội dung
```bash
#!/bin/bash
### Server Active check
WEBSERVER_CHECK=127.0.0.1
STATUS_CODE=`curl -sL -w "%{http_code}\\n" "$WEBSERVER_CHECK" -o /dev/null`

echo $STATUS_CODE

if [ $STATUS_CODE == 200 ]
then
        echo "true"
        exit 0
elif [ $STATUS_CODE == 000 ]
then
        echo "Code fail!!"
        exit 1
else
        echo "not known"
        exit 1
fi

echo "fail all"
exit 1
```
Khởi động service Keep alived
```
systemctl start keepalived
systemctl enable keepalived
systemctl status keepalived
```

<a name="phan3"></a>
### Phần 3: Cấu hình Rsync
> (Remote Sync) là một công cụ dùng để sao chép và đồng bộ file/thư mục được sử dụng rộng rãi trong môi trường Linux. Với sự trợ giúp của rsync, bạn có thể đồng bộ dữ liệu trên local hoặc giữa các server với nhau một cách dễ dàng.

![](../images/gitlab-install-3.png)

#### Bước 1: Cấu hình tại Master Node (Git Active)
Cài đặt gói
```
yum -y install rsync
```
Cấu hình file main rsyncd.conf
```
vi /etc/rsyncd.conf
```
Nội dung
```
###
[backup]
path = /var/opt/gitlab
hosts allow = 10.200.200.229
hosts deny = *
list = true
uid = root
gid = root
read only = false
```
Khởi động
```
systemctl restart rsyncd
systemctl enable rsyncd
```

#### Bước 2: Cấu hình tại Slave (Git Passive)
Cài đặt gói
```
yum -y install rsync
```
Cấu hình file main rsyncd.conf
```
vi /etc/rsyncd.conf
```
Nội dung
```
[backup]
path = /var/opt/gitlab
hosts allow = 10.200.200.228
hosts deny = *
list = true
uid = root
gid = root
read only = false
```
Khởi động service
```
systemctl restart rsyncd
systemctl enable rsyncd
```

<a name="phan4"></a>
### Phần 4: Cấu hình ssh bỏ qua pass giữa active passive
> Hỗ trợ đồng bộ dữ liệu giữa 2 node thông qua script

> Thực hiện trên cả 2 node

__Tại cả Master và Agent__

Tạo key
```
ssh-keygen
```
Nội dung
```
Generating public/private rsa key pair.
Enter file in which to save the key (/home/jsmith/.ssh/id_rsa):[Enter key]
Enter passphrase (empty for no passphrase): [Press enter key]
Enter same passphrase again: [Pess enter key]
Your identification has been saved in /home/xxx/.ssh/id_rsa.
Your public key has been saved in /home/xxx/.ssh/id_rsa.pub.
The key fingerprint is:
33:b3:fe:af:95:95:18:11:31:d5:de:96:2f:f2:35:f9 xxx@local-host
```
Chuyển key tới máy remove
```
ssh-copy-id -i ~/.ssh/id_rsa.pub remote-host
```
Nội dung
```
xxx@remote-host's password:
Now try logging into the machine, with "ssh 'remote-host'", and check in:

.ssh/authorized_keys

to make sure we haven't added extra keys that you weren't expecting.
```
Test kết nối
```
ssh remote-host
```

<a name="phan5"></a>
### Phần 5: Cấu hình đồng bộ, chịu lỗi, HA
> Script đồng bộ cho phép dữ liệu tự động đồng bộ giữa Master – Slave và cơ chế chịu lỗi khi gặp sự cố

#### Bước 1: Cấu hình Master
__Sử dụng script check-rsync.sh__
```
vi /etc/gitlab/check-rsync.sh
```
Nội dung
```bash
#!/bin/bash
### VAR
WEBSERVER_CHECK=10.200.108.229 #slave
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
  rsync -azvr --delete /var/opt/gitlab/ root@$WEBSERVER_CHECK:/var/opt/gitlab/
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
```

Bước 2: Cấu hình Slave
Sử dụng script check_fail_over.sh
```
vi /etc/gitlab/check_fail_over.sh
```
Nội dung
```bash
#!/bin/bash
### Server Active check
WEBSERVER_CHECK=10.200.200.228 #master #truong xet 1 file main config
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
```

<a name="phan1"></a>
### Cấu hình Cron
> Cron là một tiện ích cho phép thực hiện các tác vụ một cách tự động theo định kỳ, ở chế độ nền của hệ thống. Crontab (CRON TABLE) là một file chứa đựng bảng biểu (schedule) của các entries được chạy.

#### Bước 1: Cấu hình Master
Thêm lịch trình
```
crontab -e
```
Nội dung
```bash
*/5 * * * * bash /etc/gitlab/check_fail_over.sh
@reboot gitlab-ctl stop
```
Khởi động lại Cron
```
systemctl restart crond
systemctl status crond
```

#### Bước 2: Cấu hình Slave
Thêm lịch trình
```
crontab -e
```
Nội dung
```bash
*/5 * * * * bash /etc/gitlab/check_fail_over.sh
@reboot gitlab-ctl stop
```
Khởi động lại Cron
```
systemctl restart crond
systemctl status crond
```

<a name="phan6"></a>
### Phần 6: Qui trình khởi động GitLab
> Khởi động đúng theo mô hình, active – service gitlab on, passive – service gitlab off

Tại server Gitlabs:

Kiểm tra trạng thái:
```
gitlab-ctl status
```

Nếu service off, để khởi động sử dụng cmd:
```
gitlab-ctl start
```
Để stop service
```
gitlab-ctl stop
```

#### Kiểm tra log của các Server tại:
```
/var/log/script-gitlabs/master.log
/var/log/script-gitlabs/slave.log
/var/log/script-gitlabs/sync-passive-active.log
/var/log/script-gitlabs/rsync.log
```

### Lưu ý
> File source trong thư mục `lab/script demo`

> File docs trong thư mục `docs/..`
