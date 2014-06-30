#!/bin/bash

count=`ps aux | grep coffeebot.rb | wc -l`
if [ $count -eq 1 ];then
   echo "missing, starting it up"
   echo `date` >> /var/log/coffeebot/crash.log 
   nohup /root/coffeebot/coffeebot.rb 2>> /var/log/coffeebot/crash.log &
fi
sleep 2
