#!/bin/bash
# Test XU4 SJVA & OMV 5 Setup
echo "Time Zone Setup"
apt install tzdata locales
cp -p /usr/share/zoneinfo/Asia/Seoul /etc/localtime
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_MESSAGES=POSIX
localectl set-locale LANG=en_US.UTF-8

echo " - Killing filebrowser process"
pgrep -a filebrowser | awk '{ print $1 }' | xargs kill -9 >/dev/null 2>&1
sleep 1

echo "dns setting.."
rm -f /etc/resolv.conf
cat >> /etc/resolv.conf << 'EOF'
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

echo "Update & Upgrade"
apt update -y && apt -y upgrade && apt -y install armbian-config

echo "Base Setup"
apt install -y python python-pip python-dev python-setuptools git   
apt install -y libffi-dev libxml2-dev libzbar-dev libxslt-dev libzbar0 zlib1g-dev libssl-dev
#apt install -y libjpeg8-dev 
apt install -y python-lxml python-wheel python-wheel
apt install -y dialog apt-utils vim
 
echo "Java setting.."
apt -y install default-jdk

echo "Rclone setting.."
apt -y install curl busybox
curl https://rclone.org/install.sh | bash

echo "ffmpeg setting.."
apt -y install ffmpeg

echo "filebrowser setting.."
curl -fsSL https://filebrowser.xyz/get.sh | bash

echo "redis-server setting.."
apt -y install redis

echo "vnstat setting.."
apt -y install vnstat net-tools

echo "SJVA2 Downloading.." 
cd /home
git clone https://github.com/soju6jan/SJVA2.git

echo "SJVA2 pip setting.."
cd SJVA2
python -m pip install --upgrade pip
pip install --upgrade setuptools
pip install -r requirements.txt

echo "Running file modify.."
rm -f my_start.sh
rm -f my_worker_start.sh
cat >> my_start.sh << 'EOF'
#! /bin/sh
export REDIS_PORT="46379"
export FILEBROWSER_PORT="9998"
export CELERY_MONOTORING_PORT="9997"
su -c "nohup redis-server --port ${REDIS_PORT} &" >/dev/null 2>&1
su -c "nohup filebrowser -a 0.0.0.0 -p ${FILEBROWSER_PORT} -r / -d ./data/db/filebrowser.db &" >/dev/null 2>&1
COUNT=0
while [ 1 ];
do
    git reset --hard HEAD
    git pull
    chmod 777 .
    chmod -R 777 ./bin
    if [ -d "./data/custom" ]; then
        chmod -R +x ./data/custom
    fi
    FILENAME="update_requirements.txt"
    if [ -f "$FILENAME" ] ; then
        pip install -r update_requirements.txt
    fi
    export FLASK_APP=sjva.py
    if [ ! -d "./migrations" ] && [ -f "./data/db/sjva.db" ]; then
        python -OO -m flask db init
    fi
    if [ -d "./migrations" ]; then
        python -OO -m flask db migrate
        python -OO -m flask db upgrade
    fi
    su -c "nohup sh ./my_worker_start.sh &" >/dev/null 2>&1
    python -OO sjva.py 0 ${COUNT}
    RESULT=$?
    echo "PYTHON EXIT CODE : ${RESULT}.............."
    if [ "$RESULT" = "0" ]; then
        echo 'FINISH....'
        break
    else
        echo 'REPEAT....'
    fi
    COUNT=`expr $COUNT + 1`
done
EOF
cat >> my_worker_start.sh << 'EOF'
#! /bin/sh
export C_FORCE_ROOT='true'
pgrep -a python | grep celery | awk '{ print $1 }' | xargs kill -9 >/dev/null 2>&1
su -c "nohup python -OO /usr/local/bin/celery -A sjva.celery flower --port=${CELERY_MONOTORING_PORT} &" >/dev/null 2>&1
su -c "python -OO /usr/local/bin/celery worker -A sjva.celery --loglevel=info" >/dev/null 2>&1
EOF
chmod 777 my_start.sh
chmod 777 my_worker_start.sh

echo "Register SJVA2 to system service.."
rm -f /etc/init.d/sjva2
cat >> /etc/init.d/sjva2 << 'EOF'
#!/bin/sh
### BEGIN INIT INFO
# Provides: skeleton
# Required-Start: $remote_fs $syslog
# Required-Stop: $remote_fs $syslog
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Example initscript
# Description: This file should be used to construct scripts to be
# placed in /etc/init.d.
# Modified by jassmusic
### END INIT INFO
sjva2_running=`pgrep -a my_start | awk '{ print $1 }'`
python_running=`pgrep -a python | grep sjva.py | awk '{ print $1 }'`
celery_running=`pgrep -a python | grep celery | awk '{ print $1 }'`
redis_running=`pgrep -a redis-server | awk '{ print $1 }'`
filebrowser_running=`pgrep -a filebrowser | awk '{ print $1 }'`
case "$1" in
start)
if [ -z "$sjva2_running" ]; then
echo -n "Starting sjva2: "
cd /home/SJVA2
su -c "nohup ./my_start.sh &" >/dev/null 2>&1
sleep 1
echo "done"
else
echo "sjva2 already running"
exit 0
fi
;;
stop)
if [ -z "$sjva2_running" ]; then
echo -n "Checking sjva2: "
pgrep -a my_start | awk '{ print $1 }' | xargs kill -9 >/dev/null 2>&1
pgrep -a python | grep sjva.py | awk '{ print $1 }' | xargs kill -9 >/dev/null 2>&1
pgrep -a python | grep sjva.celery | awk '{ print $1 }' | xargs kill -9 >/dev/null 2>&1
pgrep -a redis-server | awk '{ print $1 }' | xargs kill -9 >/dev/null 2>&1
pgrep -a filebrowser | awk '{ print $1 }' | xargs kill -9 >/dev/null 2>&1
sleep 1
echo "done"
echo "sjva2 is not running (no process found)..."
exit 0
fi
echo -n "Killing sjva2: "
pgrep -a my_start | awk '{ print $1 }' | xargs kill -9 >/dev/null 2>&1
pgrep -a python | grep sjva.py | awk '{ print $1 }' | xargs kill -9 >/dev/null 2>&1
pgrep -a python | grep sjva.celery | awk '{ print $1 }' | xargs kill -9 >/dev/null 2>&1
pgrep -a redis-server | awk '{ print $1 }' | xargs kill -9 >/dev/null 2>&1
pgrep -a filebrowser | awk '{ print $1 }' | xargs kill -9 >/dev/null 2>&1
sleep 1
echo "done"
;;
restart)
sh $0 stop
sh $0 start
;;
status)
if [ -z "$sjva2_running" ]; then
echo "It seems that sjva isn't running (no process found)."
else
echo "sjva2 process running."
fi
;;
*)
echo "Usage: $0 {start|stop|restart|status}"
exit 1
;;
esac
exit 0
EOF
chmod +x /etc/init.d/sjva2
update-rc.d sjva2 defaults
cd /home/SJVA2

echo "install OMV5"
wget -O - https://github.com/OpenMediaVault-Plugin-Developers/installScript/raw/master/install | sudo bash

echo "All END Reboot"
sleep 2
reboot
