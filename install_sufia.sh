#!/bin/bash
set -o errexit -o nounset -o xtrace -o pipefail

INSTALL_USER="vagrant"
if [ $# -ge 1 ]; then
  INSTALL_USER="$1"
fi
if [ $# -ge 2 ]; then
  shift;
  echo -n "Ignoring extra arguments: $@"
fi
INSTALL_DIR="/home/$INSTALL_USER"
SERVER_HOSTNAME="localhost"
APP_ENV="development"
HYDRA_HEAD="sufia_app"
HYDRA_HEAD_DIR="$INSTALL_DIR/$HYDRA_HEAD"
RUN_AS_INSTALLUSER="sudo -H -u $INSTALL_USER"
FITS_PACKAGE="fits-0.6.2"
RUBY_PACKAGE="ruby2.2"
PASSENGER_REPO="/etc/apt/sources.list.d/passenger.list"
PASSENGER_INSTANCES="1"
NGINX_CONF_DIR="/etc/nginx"
NGINX_CONF_FILE="$NGINX_CONF_DIR/nginx.conf"
NGINX_SITE="$NGINX_CONF_DIR/sites-available/$HYDRA_HEAD.site"
NGINX_MAX_UPLOAD_SIZE="200M"
SSL_CERT_DIR="/etc/ssl/local/certs"
SSL_CERT="$SSL_CERT_DIR/$HYDRA_HEAD-crt.pem"
SSL_KEY_DIR="/etc/ssl/local/private"
SSL_KEY="$SSL_KEY_DIR/$HYDRA_HEAD-key.pem"

apt-get update
apt-get upgrade -y

# Install Java 8 and make it the default Java
add-apt-repository -y ppa:webupd8team/java
apt-get update -y
echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
apt-get install -y oracle-java8-installer
update-java-alternatives -s java-8-oracle

# Install FITS to /opt/fits
apt-get install -y unzip
TMPFILE=$(mktemp -d)
cd "$TMPFILE"
wget --quiet "http://projects.iq.harvard.edu/files/fits/files/${FITS_PACKAGE}.zip"
unzip -q "${FITS_PACKAGE}.zip" -d /opt
ln -sf "/opt/${FITS_PACKAGE}" /opt/fits
chmod a+x /opt/fits/fits.sh
rm -rf "$TMPFILE"
cd $INSTALL_DIR

# Install ffmpeg
# Instructions from the static builds link on this page: https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu
add-apt-repository -y ppa:mc3man/trusty-media
apt-get update
apt-get install -y ffmpeg

# Install nodejs from Nodesource
curl -sL https://deb.nodesource.com/setup | bash -
apt-get install -y nodejs

# Install Redis, ImageMagick, PhantomJS, and Libre Office
apt-get install -y redis-server imagemagick phantomjs libreoffice
# Install Ruby via Brightbox repository
add-apt-repository -y ppa:brightbox/ruby-ng
apt-get update
apt-get install -y $RUBY_PACKAGE ${RUBY_PACKAGE}-dev

# Install Nginx and Passenger.
# Install PGP key and add HTTPS support for APT
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7
apt-get install -y apt-transport-https ca-certificates
# Add APT repository
echo "deb https://oss-binaries.phusionpassenger.com/apt/passenger trusty main" > $PASSENGER_REPO
chown root: $PASSENGER_REPO
chmod 600 $PASSENGER_REPO
apt-get update
# Install Nginx and Passenger
apt-get install -y nginx-extras passenger
# Uncomment passenger_root and passenger_ruby lines from config file
TMPFILE=`/bin/mktemp`
cat $NGINX_CONF_FILE | \
  sed "s/worker_processes .\+;/worker_processes auto;/" | \
  sed "s/# passenger_root/passenger_root/" | \
  sed "s/# passenger_ruby/passenger_ruby/" > $TMPFILE
sed "1ienv PATH;" < $TMPFILE > $NGINX_CONF_FILE
chown root: $NGINX_CONF_FILE
chmod 644 $NGINX_CONF_FILE
# Disable the default site
unlink ${NGINX_CONF_DIR}/sites-enabled/default
# Stop Nginx until the application is installed
service nginx stop

# Configure Passenger to serve our site.
# Create the virtual host for our Sufia application
cat > $TMPFILE <<HereDoc
passenger_max_pool_size ${PASSENGER_INSTANCES};
passenger_pre_start http://${SERVER_HOSTNAME};

server {
    listen 80;
    listen 443 ssl;
    client_max_body_size ${NGINX_MAX_UPLOAD_SIZE};
    passenger_min_instances ${PASSENGER_INSTANCES};
    root ${HYDRA_HEAD_DIR}/public;
    passenger_enabled on;
    passenger_app_env ${APP_ENV};
    server_name ${SERVER_HOSTNAME};
    ssl_certificate ${SSL_CERT};
    ssl_certificate_key ${SSL_KEY};
}
HereDoc
# Install the virtual host config as an available site
install -o root -g root -m 644 $TMPFILE $NGINX_SITE
rm $TMPFILE
# Enable the site just created
link $NGINX_SITE ${NGINX_CONF_DIR}/sites-enabled/${HYDRA_HEAD}.site
# Create the directories for the SSL certificate files
mkdir -p $SSL_CERT_DIR
mkdir -p $SSL_KEY_DIR
# Create an SSL certificate
SUBJECT="/C=US/ST=Virginia/O=Virginia Tech/localityName=Blacksburg/commonName=$SERVER_HOSTNAME/organizationalUnitName=University Libraries"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$SSL_KEY" \
    -out "$SSL_CERT" -subj "$SUBJECT"
chmod 444 "$SSL_CERT"
chown root "$SSL_CERT"
chmod 400 "$SSL_KEY"
chown root "$SSL_KEY"

# Create Hydra head
apt-get install -y git sqlite3 libsqlite3-dev zlib1g-dev build-essential
gem install rails -v "~> 4.2.5"
$RUN_AS_INSTALLUSER rails new "$HYDRA_HEAD"
cd "$HYDRA_HEAD_DIR"
$RUN_AS_INSTALLUSER cat >> Gemfile <<EOF
gem 'sufia', '6.6.0'
gem 'kaminari', github: 'jcoyne/kaminari', branch: 'sufia'  # required to handle pagination properly in dashboard. See https://github.com/amatsuda/kaminari/pull/322
EOF
$RUN_AS_INSTALLUSER bundle install
$RUN_AS_INSTALLUSER bundle exec rails generate sufia:install -f
$RUN_AS_INSTALLUSER bundle exec rake db:migrate
$RUN_AS_INSTALLUSER cat > config/fedora.yml <<FEDORA_EOF
development:
  user: fedoraAdmin
  password: fedoraAdmin
  url: http://127.0.0.1:<%= ENV['FCREPO_DEVELOPMENT_PORT'] || 8983 %>/fedora/rest
  base_path: /dev
test:
  user: fedoraAdmin
  password: fedoraAdmin
  url: http://127.0.0.1:<%= ENV['FCREPO_TEST_PORT'] || 8983 %>/fedora/rest
  base_path: /test
production:
  user: fedoraAdmin
  password: fedoraAdmin
  url: http://127.0.0.1:8983/fedora/rest
  base_path: /prod
FEDORA_EOF
$RUN_AS_INSTALLUSER cat > config/solr.yml <<SOLR_EOF
development:
  url: http://127.0.0.1:<%= ENV['SOLR_TEST_PORT'] || 8983 %>/solr/development
test:
  url: http://127.0.0.1:<%= ENV['SOLR_TEST_PORT'] || 8983 %>/solr/test
production:
  url: http://your.production.server:8080/bl_solr/core0
SOLR_EOF
$RUN_AS_INSTALLUSER sed -i "s@# config.fits_path = \".*\"@config.fits_path = \"/opt/fits/fits.sh\"@" config/initializers/sufia.rb
$RUN_AS_INSTALLUSER bundle exec rake jetty:clean
$RUN_AS_INSTALLUSER bundle exec rake sufia:jetty:config
cat > /etc/init.d/sufia_services <<END_OF_INIT_SCRIPT
#!/bin/sh
# Init script to start up Sufia services (hydra-jetty and resque-pool)
# Warning: This script is auto-generated.

### BEGIN INIT INFO
# Provides: sufia_services
# Required-Start:    \$remote_fs \$syslog redis-server
# Required-Stop:     \$remote_fs \$syslog redis-server
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Description:       Controls Sufia Services
### END INIT INFO

RESQUE_POOL_PIDFILE="${HYDRA_HEAD_DIR}/tmp/pids/resque-pool.pid"
DAEMON="/usr/local/bin/resque-pool"
# verify the specified run as user exists
runas_uid=\$(id -u $INSTALL_USER)
if [ \$? -ne 0 ]; then
  echo "User $INSTALL_USER not found! Please create the $INSTALL_USER user before running this script."
  exit 1
fi
. /lib/lsb/init-functions

start() {
  cd "${HYDRA_HEAD_DIR}"
  sudo -H -u $INSTALL_USER RAILS_ENV=${APP_ENV} bundle exec rake jetty:start
  sudo -H -u $INSTALL_USER RAILS_ENV=${APP_ENV} RUN_AT_EXIT_HOOKS=true TERM_CHILD=1 bundle exec resque-pool --daemon --environment $APP_ENV --pidfile \$RESQUE_POOL_PIDFILE
}

stop() {
  cd "${HYDRA_HEAD_DIR}"
  sudo -H -u $INSTALL_USER RAILS_ENV=${APP_ENV} bundle exec rake jetty:stop
  if [ -f \$RESQUE_POOL_PIDFILE ]; then
    kill -QUIT \$(cat \$RESQUE_POOL_PIDFILE)
    while ps agx | grep resque | egrep -qv 'rc[0-9]\.d|init\.d|service|grep'; do sleep 1; done
  fi
}

case "\$1" in
  start)   start ;;
  stop)    stop ;;
  restart) stop
           sleep 1
           start
           ;;
  status)  status_of_proc -p "\$RESQUE_POOL_PIDFILE" "\$DAEMON" "resque-pool" && exit 0 || exit \$?
           ;;
  *)
    echo "Usage: \$0 {start|stop|restart|status}"
    exit
esac
END_OF_INIT_SCRIPT
chmod 755 /etc/init.d/sufia_services
chown root:root /etc/init.d/sufia_services
update-rc.d sufia_services defaults
# Start services
service sufia_services start
service nginx start
