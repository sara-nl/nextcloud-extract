# Extract
Place this app in **nextcloud/apps/**

This app does only support local external storage backend

## Supported

* Zip 
* Rar
* Tar
* Gzip
* 7z
* Deb
* Bzip2

## Requirements

* Rar PHP extension 
```bash
pecl -v install rar ## or ## sudo apt-get install unrar
```

* p7zip and p7zip-full 

## Steps to install p7zip on Linux &raquo; Ubuntu and Fedora or Alma / Rocky Linux

#### MacOS

```bash
brew install p7zip
```

#### Ubuntu

```bash
sudo apt-get install p7zip p7zip-full
```

#### Almalinux or Rocky Linux 9.x
#### Download and install manually 

```bash
wget https://dl.fedoraproject.org/pub/epel/9/Everything/x86_64/Packages/p/p7zip-16.02-20.el9.x86_64.rpm
wget https://dl.fedoraproject.org/pub/epel/9/Everything/x86_64/Packages/p/p7zip-plugins-16.02-20.el9.x86_64.rpm

sudo rpm -U --quiet p7zip-16.02-20.el9.x86_64.rpm
sudo rpm -U --quiet p7zip-plugins-16.02-20.el9.x86_64.rpm
```

or

```bash
sudo dnf install -y epel-release
sudo dnf install -y p7zip p7zip-plugins
```

#### Download and install manually 
In case of connectivity [or any other] issues, please follow these steps to download and install the following packages directly.

```bash
wget https://www.mirrorservice.org/sites/dl.fedoraproject.org/pub/epel/6/x86_64/Packages/p/p7zip-16.02-10.el6.x86_64.rpm
wget https://www.mirrorservice.org/sites/dl.fedoraproject.org/pub/epel/6/x86_64/Packages/p/p7zip-plugins-16.02-10.el6.x86_64.rpm

sudo rpm -U --quiet p7zip-16.02-10.el6.x86_64.rpm
sudo rpm -U --quiet p7zip-plugins-16.02-10.el6.x86_64.rpm
```

## Tests

The end-to-end test starts the official Nextcloud Docker image, installs 7-Zip and the app from
this checkout, uploads zip, tar, tar.gz, tar.bz2, gz and 7z archives and extracts them through the
same endpoint the file action calls. It also checks access for anonymous users and requests
without a request token, that the Files page loads the file action, that the file action is shown
for the mime type Nextcloud reports for each archive, and that files with a name Nextcloud forbids
(such as `.htaccess`) are removed after extracting. Errors in the Nextcloud log, and PHP warnings
from this app, fail the run.

```bash
tests/e2e/run-docker.sh 35          # image tag: 34, 35, latest, ...
FORCE_ENABLE=1 tests/e2e/run-docker.sh latest   # a version newer than max-version
```

It needs Docker, curl and python3. `tests/e2e/e2e.sh` can also test an existing server over ssh;
see the comment at the top of the script.

GitHub Actions lints the PHP code on PHP 8.2 and 8.5, checks that the committed files in `js/`
match a fresh build, and runs the end-to-end test on Nextcloud 34 and 35 for every pull request,
and weekly against the newest Nextcloud release.

## TODO

* Add password support
* Add viewer for archives
* Support nextcloud's encryption module

## Preview

![alt text](https://raw.githubusercontent.com/PaulLereverend/NextcloudExtract/master/img/extract.png)
