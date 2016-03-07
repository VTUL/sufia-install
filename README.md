# Sufia Development Environment

This [Vagrant](https://www.vagrantup.com/) environment enables a developer to install and run a Sufia application either locally, via [VirtualBox](http://www.virtualbox.org), or to bring up an Amazon Web Services (AWS) server instead.

In either case the application is installed via the provisioning script, `install_sufia.sh`.  This script downloads and installs all the necessary components and also sets up startup scripts that ensure the Sufia application is run when the system boots.

The installed Sufia application runs via Nginx/Passenger.  It can be accessed either via HTTP or HTTPS.  The server itself can be logged into via SSH.  In the case of an AWS install, an SSH key is required to be able to log in.  To log in to `somehost.amazonaws.com`, use a command such as the following:

```
ssh -i /path/to/keypair/secret/key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@somehost.amazonaws.com
```

With a local VirtualBox Vagrant install, `vagrant ssh` can be used to log in to the server running the application.

The user `vagrant` is used as the login user for the VirtualBox environment; `ubuntu` is used for the AWS environment.  In either case, this user can perform commands as the `root` user via `sudo`.

### Sufia Services

For the application to run, the following services are needed:

- Nginx/Passenger
- Fedora
- Solr
- Redis/Resque

Passenger is run via Nginx.  The command `sudo service nginx restart` can be used to restart Nginx/Passenger (and the Rails application).  Nginx listens on ports 80 and 443.

Fedora and Solr are provided via `hydra-jetty`, which listens on port 8983.  The URL `http://127.0.0.1:8983` can be used to access these services, e.g., to check they are running.

Redis is provided by the `redis-server` system service.  Resque is provided by a `rake` task that is run via a system service.

Both `hydra-jetty` and Resque can be started and stopped by means of the `sufia_services` system service, which is set to run at boot.

The command `sudo service sufia_services start` can be used to start Fedora/Solr/Resque and `sudo service sufia_services stop` can be used to stop them.  Note: the Sufia application will not run properly if Fedora or Solr are not running.  Background jobs will not be processed if Redis or Resque are not running.

### Sufia application

The Sufia application is in the `sufia_app` directory in the user's home directory.  This is a Ruby on Rails application.

When running at, e.g., `example.com`, the running application can be accessed either via `http://example.com` or `https://example.com`.

From the application home page, the `Login` button in the top-right can be used to create a user.  Select the "Sign up" link on the "Log in" page and then fill out the information on the "Sign up" page.  This will create a user and log it in.
