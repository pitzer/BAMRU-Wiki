## BAMRU-Wiki

### Overview

This repo contains the wiki code - based on MediaWiki.

Deployment is done via Capistrano.

The app-server is the built-in WebServer in PHP5.4, managed by Upstart.

Nginx is used as a reverse proxy/app-server front end.

The database is sqlite.  We only store text data in the wiki - images are
stored on the 'file' page of the intranet.  Backups are done via scp-ing the
sqlite file.

### Single-Sign-On

There is a simple single-sign-on script.

See more at https://github.com/andyl/mwra
