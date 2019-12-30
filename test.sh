#!/bin/bash
# Test XU4 SJVA & OMV 5 Setup
apt update -y && apt -y upgrade && apt -y install armbian-config
apt install -y python-pip python-setuptools libzbar-dev libzbar0
apt install -y libxml2-dev libxslt-dev python-dev libssl-dev
apt install -y libffi-dev libjpeg8-dev zlib1g-dev
apt install -y python-lxml python-wheel python-wheel
