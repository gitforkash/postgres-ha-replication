#!/bin/bash
echo "Deleting all postgres packages"
dpkg --list | grep postgres | sudo apt-get purge --auto-remove

sudo apt-get -y purge --auto-remove postgresql-14-citus-10.2
sudo apt-get -y purge --auto-remove postgresql-10
sudo apt-get -y purge --auto-remove postgresql-14
sudo apt-get -y purge --auto-remove postgresql-14-auto-failover-1.6
sudo apt-get -y purge --auto-remove postgresql-client-10
sudo apt-get -y purge --auto-remove postgresql-client-14
sudo apt-get -y purge --auto-remove postgresql-client-common
sudo apt-get -y purge --auto-remove postgresql-common
sudo apt-get -y purge --auto-remove pgdg-keyring
sudo apt-get -y purge --auto-remove postgresql-client-14
sudo apt-get -y purge --auto-remove postgresql-client-common
sudo rm -r /var/lib/postgresql
sudo rm -r /etc/postgresql-common
sudo rm -r /var/log/postgresql
sudo rm -r /etc/postgresql