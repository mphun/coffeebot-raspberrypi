#!/bin/bash

ping 199.30.89.24 -c 1 
if [ $? -ne 0 ]; then
  shutdown -r now 
fi
