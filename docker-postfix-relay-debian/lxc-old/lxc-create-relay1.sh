######RELAY#######
#!/bin/bash

#debian defaults the installation to ${HOME}/.local/share/lxc
#ubuntu apparently defaults to /var/lib/lxc/
#we stick to debian default cause this is for debian
lxc-create -n relay1 -t download -- -d debian -r buster -a amd64 --keyserver hkp://keys.openpgp.org:80

#An example of how you can move a container and retain permissions
#rsync -aogzHAXER --numeric-ids --inplace --no-whole-file --delete-delay --force --human-readable /src/location/relay1  ${HOME}/.local/share/lxc/relay1

#check the config file in repo for an example of what it should look like

#start the relay1 container
lxc-start -n relay1 -d

#attach to the container.  Now interacting as root of relay1
lxc-attach -n relay1

#from within relay1
#packages I consider must have for the container
apt-get install nano

#packages for the relay1 and start the install
apt-get install postfix mailutils rsyslog

#Choose Internet site, then default since we are just relaying

#check main.cf for an example config, you might want to make your interface static ip
#now, make your changes and then..
systemctl restart postfix
echo "This is a test from our new virtualized container relay server" | mail -s "Container New Relay Test Email" youremailaddress@here.com -a "FROM:youremailaddress@here.com"

######RELAY#######
