!# /bin/bash
# Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова
touch /etc/sysconfig/watchlog
echo 'WORD=ALERT
LOG=/var/log/watchlog.log' >/etc/sysconfig/watchlog

touch /var/log/watchlog.log
echo 'khskj
dsadads
dasdaw
sdasc
adsasds
ALERT
dasds
vfvfv
ALERT
sdsds' > /var/log/watchlog.log

touch /opt/watchlog.sh
echo '#!/bin/bash
WORD=$1
LOG=$2
DATE=`date`
if grep $WORD $LOG &> /dev/null
then
logger "$DATE: I found word, Master!"
else
exit 0
fi' > /opt/watchlog.sh

chmod -R 0700 /opt/watchlog.sh

touch /etc/systemd/system/watchlog.service
echo '[Unit]
Description=My watchlog service
[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG' > /etc/systemd/system/watchlog.service

touch /etc/systemd/system/watchlog.timer
echo 'Description=Run watchlog script every 30 second
[Timer]
# Run every 30 second
OnCalendar=*-*-* *:*:0/30
AccuracySec=1s
Unit=watchlog.service
[Install]
WantedBy=multi-user.target' > /etc/systemd/system/watchlog.timer

systemctl daemon-reload
systemctl enable watchlog.timer
systemctl start watchlog.timer
systemctl enable watchlog.service
systemctl start watchlog.service

# Из репозитория epel установить spawn-fcgi и переписать init-скрипт на unit-файл
yum install epel-release -y && yum install spawn-fcgi php php-cli mod_fcgid httpd -y

echo 'SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u apache -g apache -s $SOCKET -S -M 0600 -C 32 -F 1 -P /var/run/spawn-fcgi.pid -- /usr/bin/php-cgi"' > /etc/sysconfig/spawn-fcgi

touch /etc/systemd/system/spawn-fcgi.service
echo '[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target
[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
KillMode=process
[Install]
WantedBy=multi-user.target' > /etc/systemd/system/spawn-fcgi.service

systemctl daemon-reload
systemctl enable spawn-fcgi
systemctl start spawn-fcgi

# Дополнить юнит-файл apache httpd возможностью запустить несколько инстансов сервера с разными конфигами
touch /etc/sysconfig/httpd-first
echo 'OPTIONS=-f conf/first.conf' > /etc/sysconfig/httpd-first

touch /etc/sysconfig/httpd-second
echo 'OPTIONS=-f conf/second.conf' > /etc/sysconfig/httpd-second

cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/first.conf
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/second.conf

echo 'PidFile /var/run/httpd-first.pid
ServerName localhost' >> /etc/httpd/conf/first.conf

echo 'PidFile /var/run/httpd-second.pid
ServerName localhost' >> /etc/httpd/conf/second.conf

cp /usr/lib/systemd/system/httpd.service /etc/systemd/system
mv /etc/systemd/system/httpd.service /etc/systemd/system/httpd@.service

sed -i '/Listen 80/c Listen 81' /etc/httpd/conf/first.conf
sed -i '/Listen 80/c Listen 82' /etc/httpd/conf/second.conf

echo '[Unit]
Description=The Apache HTTP Server
After=network.target remote-fs.target nss-lookup.target
Documentation=man:httpd(8)
Documentation=man:apachectl(8)
[Service]
Type=notify
EnvironmentFile=/etc/sysconfig/httpd-%I
ExecStart=/usr/sbin/httpd $OPTIONS -DFOREGROUND
ExecReload=/usr/sbin/httpd $OPTIONS -k graceful
ExecStop=/bin/kill -WINCH ${MAINPID}
KillSignal=SIGCONT
PrivateTmp=true
[Install]
WantedBy=multi-user.target' > /etc/systemd/system/httpd@.service

setenforce 0
systemctl daemon-reload
systemctl enable httpd@first.service
systemctl enable httpd@second.service
systemctl start httpd@first.service
systemctl start httpd@second.service