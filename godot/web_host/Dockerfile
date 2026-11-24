# Serves the browser build of Gullhaven (index.html, .wasm, .pck...) with Caddy.
# The CI copies this next to the exported files on the godot-web branch; Railway builds it.
FROM caddy:2.8.4-alpine
COPY Caddyfile /etc/caddy/Caddyfile
COPY . /srv
