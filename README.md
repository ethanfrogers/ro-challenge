# Coding Challenge

This project creates a single EC2 Instance running a webapp, service traffic on port 3000.

## Details
* Create a Security Group that allows ingress on port 3000
* Create EC2 instance (CoreOS) running a Docker container (`ethanfrogers/areyousilly:v0.0.1`) using Ignition to bootstrap the instance
* Monitor creation and display the DNS of the instance for usage

## Dependencies

* `bash`
* `jq`
* `awscli`
* (Not Required) `coreos-ct` to generate igniton config from cloud-config.

## Usage

Start instance and monitor until ready. The URL for the final web page will be printed.

```bash
$ bash up.sh
```

## Generating Ignition Config

Using `coreos-ct`, generate the Ignition configuring using `ct -in-file systemd.yaml`. The one used for User Data has been committed with this repo.

## Webapp

The "webapp" used for this sample is a simple Nginx server serving a static HTML page. This is the Dockerfile used to create it.

```
FROM nginx:alpine

ADD index.html /data/www/index.html
ADD ro.site.conf /etc/nginx/conf.d/
```

And the Nginx config (`ro.site.conf`)

```
server {
    listen 3000;
    root /data/www;
}
```