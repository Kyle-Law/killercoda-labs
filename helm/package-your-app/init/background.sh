#!/bin/bash

mkdir -p /root/site

cat > /root/site/index.html <<'HTMLEOF'
<!doctype html>
<html>
  <head><title>My Site</title></head>
  <body>
    <h1>Hello from somewhere</h1>
    <p>Served by nginx on Kubernetes.</p>
  </body>
</html>
HTMLEOF

touch /tmp/.initfinished
