#cloud-config

package_upgrade: true
packages:
  - fish
  - atop
  - docker.io
  - ufw
  - unattended-upgrades

ssh_pwauth: no
users:
  - name: johan
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    shell: /usr/bin/fish
    groups: [users, docker]
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAzTqFM62DY6nnBSEpO6lnFp80cAqs12rIfZ9iDZh/TvXuvVgrsKPaKTM5fLiulH+CntCxjmywEochYrLUiq2RnVVaoKGQsdRdCY9UGNhAK5l4v+5V5DiZBxVCEgfYwIdw1Jya+vMGKxhZ0VQprj5Yw98OfwvyX5ZksIJnHevNW+gYkeZtr0D8ETatx2ph7JI34bkSOQG607aaed8YB2U7oziTHiiuD553bSoVP26HozhLViliLGaGNOdhLZR8ionZKmc6zCrzSDb2iGPUOdjalYVxi9sqLjHwo0Mfj40AzsRYEhJ1E0LrTNA3pSjJULCWdheDEjzXpUViJlvN/2/HhQ== johan@ijohan.nl
  - name: stitch
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    shell: /usr/bin/fish
    groups: [users, docker]
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDSD/TFYNq8V/RofrxLZWiPpdM/bj3b6vto+oRhfAb+4gsfsyxbrpETvHKdahCiJTZA+jheJQdaS2IWkrpZw1sCV0pSMcD6aZJWaDomfY2wNkrNs69mDzIL3HCsqUOVft5Md46Uh21+2vLIFgPLLrn58wOBszCK5DFTTQ9VrAirpwsaZ/rJj1iFwd+35MJVDe6K5LDF1tVEJl4MdqOs2Yhi25Zuz/ynP7zeF6420arqbbXjlSIDHbTjHJ54rBvDHqhg1cuYN4CGc3Fx7NTHfSYX4tlUvVS0EDLcNXWN+QlU4EI7qXHLjGastc7UqnLc4oFivQUOjlVFizF+hghb14MFYrAegTbzdS4kAROXLv/SVr360SVXfHdL2I3AE5oC9/IEsDXiWHEPZv/OX2t/reuCkt3hIZ4MQRZyXsO5TaDrJb8mnVIpbXOGrzlQ0Eec5IvEVotz0wLxK3zOk/Hs0oTOxpbryg9j5iMBQ2CyXBR3Er0YkPeuWjj3YMNbO33yaaER+EZXdg/cfYnuowM0wGXjYwmASTzNX4CDT1VjxS3H3V6+wMxM9aNmk+kFumGtW8b9VQNC55hokK4QeCteBv2bS99+Vnki0MfGI+1H1ljviJrXJ8EeYmY15CgPRtjYPiHRZdCuLTRR//4ZaZMbCussvOlGAxZ05LcIC5fiPmiHvQ==

write_files:
  - path: /srv/traefik/traefik.toml
    content: |
      logLevel = "INFO"
      defaultEntryPoints = ["http", "https"]

      [entryPoints]
      [entryPoints.http]
      address = ":80"
          [entryPoints.http.redirect]
          entryPoint = "https"

      [entryPoints.https]
      address = ":443"
          [entryPoints.https.tls]

      [entryPoints.traefik]
      address = ":8000"

      [docker]
      endpoint = "unix:///var/run/docker.sock"
      domain = "${realm}"
      watch = true
      exposedByDefault = false

      [acme]
      email = "bofh@ijohan.nl"
      storage = "acme.json"
      entryPoint = "https"
          [acme.httpChallenge]
          entryPoint = "http"
      [[acme.domains]]
      main = "${project}.${realm}"

      [api]
      entryPoint = "traefik"
      dashboard = true

      [accesslog]

  - path: /srv/maintenance/index.html
    content: |
      <h1>Sorry, we are currently down for maintenance</h1>

runcmd:
  # configure firewall
  - ufw allow 22/tcp
  - ufw allow 80/tcp
  - ufw allow 443/tcp
  - ufw --force enable

  - docker network create ${project}

  # traffic router
  - docker run --restart always -d --net ${project} --name traefik -v /srv/traefik/traefik.toml:/etc/traefik/traefik.toml -v /var/run/docker.sock:/var/run/docker.sock:ro -p 80:80 -p 443:443 -p 8000:8000 traefik:latest
  # fallback/maintenance host
  - docker run --restart always -d --net ${project} --label traefik.enable=true --label traefik.frontend.priority=1 --label traefik.frontend.rule=Path:/ --label traefik.port=80 --name maintenance --volume /srv/maintenance/:/srv/www/ --workdir /srv/www/ --name maintenance python:3 python -m http.server 80

  # database
  - |
    docker run --restart always -d --net ${project} --name ${project}-db \
      -e POSTGRES_USER=${project} \
      -e POSTGRES_PASSWORD=${project} \
      -e POSTGRES_DB=${project} \
      postgres:11
  # dashboard instance
  - |
    docker run --restart always -d --net ${project} \
      --label traefik.enable=true \
      --label traefik.frontend.priority=10 \
      -e SECRET_KEY="bla" \
      -e FIELD_ENCRYPTION_KEY="bla" \
      -e ALLOWED_HOSTS="${project}.${realm}" \
      -e DJANGO_DATABASE=production \
      -e DB_ENGINE=postgresql_psycopg2 \
      -e DB_NAME=${project} \
      -e DB_USER=${project} \
      -e DB_PASSWORD=${project} \
      -e DB_HOST=${project}-db \
      --name ${project} \
      ${image}:latest
  # initialize database
  - |
    docker run --rm --net ${project} \
      -e SECRET_KEY="bla" \
      -e FIELD_ENCRYPTION_KEY="bla" \
      -e DJANGO_DATABASE=production \
      -e DB_ENGINE=postgresql_psycopg2 \
      -e DB_NAME=${project} \
      -e DB_USER=${project} \
      -e DB_PASSWORD=${project} \
      -e DB_HOST=${project}-db \
      --name ${project}-migration \
      ${image}:latest migrate
