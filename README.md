# docker-phpipam

phpIPAM is an open-source web IP address management application. Its goal is to provide light and simple IP address management application.

phpIPAM is developed and maintained by Miha Petkovsek, released under the GPL v3 license, project source is [here](https://github.com/phpipam/phpipam)

Learn more on [phpIPAM homepage](http://phpipam.net)

![phpIPAM logo](http://phpipam.net/wp-content/uploads/2014/12/phpipam_logo_small.png)

## How to use this Docker image

### Mysql

Run a MySQL database, dedicated to phpipam

```bash
$ docker run --name phpipam-mysql -e MYSQL_ROOT_PASSWORD=my-secret-pw -v /my_dir/phpipam:/var/lib/mysql -d mysql:5.6
```

Here, we store data on the host system under `/my_dir/phpipam` and use a specific root password. 

### Phpipam 

```bash
$ docker run -ti -d -p 443:443 -e MYSQL_ENV_MYSQL_PASSWORD=my-secret-pw --name ipam --link phpipam-mysql:mysql robwilkes/phpipam
```

We are linking the two containers and expose the HTTP port. 

### Specific integration (HTTPS, multi-host containers, etc.)

No longer creates a self-signed certificate, there are many issues with this, including issues with Firefox as the certificate is marked as a CA.

Instead, create the following two files:
ssl/private/ssl-cert-snakeoil.key
ssl/certs/ssl-cert-snakeoil.pem

And map the ssl directory as a docker volume:
```bash
$ docker run -ti -d -p 443:443 -v ssl:/etc/ssl -e MYSQL_ENV_MYSQL_PASSWORD=my-secret-pw --name ipam --link phpipam-mysql:mysql robwilkes/phpipam
```

### Configuration 

* Browse to `https://<ip>[:<specific_port>]`
* Step 1 : Choose 'Automatic database installation'

![step1](https://cloud.githubusercontent.com/assets/4225738/8746785/01758b9e-2c8d-11e5-8643-7f5862c75efe.png)

* Step 2 : Re-Enter connection information

![step2](https://cloud.githubusercontent.com/assets/4225738/8746789/0ad367e2-2c8d-11e5-80bb-f5093801e139.png)

* Note that these two first steps could be swapped by patching phpipam (see https://github.com/phpipam/phpipam/issues/25)
* Step 3 : Configure the admin user password

![step3](https://cloud.githubusercontent.com/assets/4225738/8746790/0c434bf6-2c8d-11e5-9ae7-b7d1021b7aa0.png)

* You're done ! 

![done](https://cloud.githubusercontent.com/assets/4225738/8746792/0d6fa34e-2c8d-11e5-8002-3793361ae34d.png)

### Docker compose 

You can also create an all-in-one YAML deployment descriptor with Docker compose, like this:

```yaml
version: "3.7"

services:
  phpipam:
    image: robwilkes/phpipam
    environment:
      - MYSQL_HOST=mysql
    ports:
      - "80:80"
      - "443:443"
    links:
      - mysql
    depends_on:
      - mysql
    volumes:
      - ./ssl:/etc/ssl

  mysql:
    image: mysql:5.7
    env_file:
      - db.env
    volumes:
      - ./mysql:/var/lib/mysql
```

You can also include an SMTP server by updating your docker-compose.yml as follows:

```yaml
version: "3.7"

services:
  phpipam:
    image: robwilkes/phpipam
    environment:
      - MYSQL_HOST=mysql
    ports:
      - "80:80"
      - "443:443"
    links:
      - mysql
      - smtp
    depends_on:
      - mysql
      - smtp
    volumes:
      - ./ssl:/etc/ssl

  mysql:
    image: mysql:5.7
    env_file:
      - db.env
    volumes:
      - ./mysql:/var/lib/mysql
  
  smtp:
    image: namshi/smtp
```

And next :

```bash 
$ docker-compose up -d
```

### Notes

phpIPAM is under heavy development by the amazing Miha. 
To upgrade the release version, just change the `PHPIPAM_VERSION` environment variable to the target release (see [here](https://github.com/phpipam/phpipam/releases)) 
