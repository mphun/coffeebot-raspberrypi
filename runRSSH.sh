#!/bin/bash

count=`ps aux | grep ubuntu@54.202.13.4 | wc -l`
if [ $count -eq 1 ];then
   echo "missing, starting it up"
   #ssh -f -N -R 19999:localhost:22 alee@199.30.89.24 
   #autossh -M 29001 -f -N -R 19999:localhost:22 alee@199.30.89.24
   autossh -M 29002 -f -N -R 29999:localhost:22 ubuntu@54.202.13.4 
   #ssh -N -R 29999:localhost:22 alee@199.30.89.24 -o ServerAliveInterval=30
fi
sleep 2
