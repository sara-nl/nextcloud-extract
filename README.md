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

## TODO

* Add password support
* Add viewer for archives
* Support nextcloud's encryption module

## Preview

![alt text](https://raw.githubusercontent.com/PaulLereverend/NextcloudExtract/master/img/extract.png)
