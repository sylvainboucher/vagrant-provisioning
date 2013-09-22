# Copyright (c) 2013 Sylvain Boucher
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#!/usr/bin/env bash

#variables
MONIT_USERNAME="root"
MONIT_PASSWORD="toor"

apt-get update

#install nodejs
apt-get install -y python-software-properties python g++ make
add-apt-repository ppa:chris-lea/node.js
apt-get install -y nodejs

#install nginx
apt-get install -y nginx
service nginx start
update-rc.d nginx defaults

#configure nginx
mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.BAK
cat > /etc/nginx/sites-available/default << "EOL"
upstream app_nodejs {
server 127.0.0.1:3000;
}
server {
    location / {
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_set_header X-NginX-Proxy true;
        proxy_pass http://app_nodejs;
        proxy_redirect off;
    }
}
EOL
/etc/init.d/nginx restart

#create default node server
mkdir -p /var/www
cat > /var/www/server.js << EOL
    var http = require('http');
    var server = http.createServer(function (request, response) {
      response.writeHead(200, {"Content-Type": "text/plain"});
      response.end("Default node server\n");
    });
    server.listen(3000);
    console.log("Server running at http://127.0.0.1:3000/");
EOL

#starting nodeserver
start nodeserver

#create nodeserver upstart script
cat > /etc/init/nodeserver.conf << EOL
#!upstart
    description "Node server"
    author "Sylvain Boucher"

    start on runlevel [2345]
    stop on runlevel [^2345]

    # Restart when job dies
    respawn

    # Give up restart after 5 respawns in 60 seconds
    respawn limit 5 60

    # vars
    env NODE_BIN=/usr/bin/node
    env APP_DIR=/var/www
    env SCRIPT_FILE="server.js"
    env LOG_FILE="/var/log/nodeserver.log"
    env RUN_AS="vagrant"
    #env NODE_ENV="development"
    #env SITE_URL="http://sandbox:8080"

    script
      touch $LOG_FILE
      chown $RUN_AS:$RUN_AS $LOG_FILE
      chdir $APP_DIR
      exec sudo -u $RUN_AS -E sh -c "$NODE_BIN $SCRIPT_FILE >> $LOG_FILE  2>&1"

    end script

pre-start script
# Date format same as (new Date()).toISOString() for consistency
echo "[`date -u +%Y-%m-%dT%T.%3NZ`] (sys) Starting" >> $LOG_FILE
end script

pre-stop script
echo "[`date -u +%Y-%m-%dT%T.%3NZ`] (sys) Stopping" >> $LOG_FILE
end script

post-start script
echo "===== App restarted =====" >> $LOG_FILE
end script
EOL


#install and configure monit
apt-get install -y monit
cat > /etc/monit/monitrc << EOL
set daemon 60

set httpd port 2812 and
    allow $MONIT_USERNAME:$MONIT_PASSWORD

check system nodeserver_system
      start "/sbin/start nodeserver" with timeout 60 seconds
      stop "/sbin/stop nodeserver"

check process nginx with pidfile /var/run/nginx.pid
    start program = "/etc/init.d/nginx start"
    stop program = "/etc/init.d/nginx stop"

check host nodeserver_http with address 127.0.0.1
      start "/sbin/start nodeserver" with timeout 60 seconds
      stop "/sbin/stop nodeserver"
      if failed port 80 protocol HTTP
        request /
        with timeout 5 seconds
        then restart
EOL
chmod 700 /etc/monit/monitrc
monit reload
monit start all
