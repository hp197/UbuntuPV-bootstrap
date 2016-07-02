# UbuntuPV-bootstrap
Bootstrapper files for a PV xen guest

` cd /opt/ && git clone https://github.com/hp197/UbuntuPV-bootstrap.git && rsync -a --progress UbuntuPV-bootstrap/usr/local/bin/* /usr/local/bin/ && rsync -a --progress UbuntuPV-bootstrap/lib/systemd/system/firstboot.service /lib/systemd/system/ && rm -rf /opt/UbuntuPV-bootstrap && /usr/local/bin/prep_server.sh`
