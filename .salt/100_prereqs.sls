{% set cfg = opts.ms_project %}
{% set data = cfg.data %}

{# workaround the libjpegturbo transitional
 package hell by installing it explicitly #}
prepreq-pre-{{cfg.name}}:
  pkg.{{salt['mc_pkgs.settings']()['installmode']}}:
    - pkgs:
      - libjpeg-dev

prepreq-{{cfg.name}}:
  pkg.{{salt['mc_pkgs.settings']()['installmode']}}:
    - pkgs:
      - apache2-utils
      - liblcms2-2
      - liblcms2-dev
      - autoconf
      - automake
      - build-essential
      - bzip2
      - gettext
      - git
      - groff
      - libbz2-dev
      - libcurl4-openssl-dev
      - libdb-dev
      - libgdbm-dev
      - libreadline-dev
      - libfreetype6-dev
      - libsigc++-2.0-dev
      - libsqlite0-dev
      - libsqlite3-dev
      - libtiff5
      - libtiff5-dev
      - libwebp5
      - libwebp-dev
      - libssl-dev
      - libtool
      - libxml2-dev
      - libxslt1-dev
      - libopenjpeg-dev
      {% if grains['oscodename'] in ['trusty'] %}
      - libopenjpeg2
      {% else %}
      - libopenjpeg5
      {% endif %}
      - m4
      - man-db
      - pkg-config
      - poppler-utils
      - python-dev
      - python-imaging
      - python-setuptools
      - tcl8.4
      - tcl8.4-dev
      - tcl8.5
      - tcl8.5-dev
      - tk8.5-dev
      - wv
      - zlib1g-dev

var-dirs-{{cfg.name}}:
  file.directory:
    - names:
      - {{data.front_doc_root}}
      - {{data.doc_root}}
      - {{data.ui}}
      - {{data.buildout.settings.locations['locations-blob-storage']}}
      - {{data.buildout.settings.locations['locations-blob-backup']}}
      - {{data.buildout.settings.buildout['download-cache']}}
      - {{data.buildout.settings.buildout['download-directory']}}
      - {{data.buildout.settings.buildout['parts-directory']}}
      - {{data.buildout.settings.buildout['eggs-directory']}}
    - makedirs: true
    - user: {{cfg.user}}
    - group: {{cfg.group}}
    - mode: 2770

var-dir-{{cfg.name}}:
  file.symlink:
    - name: {{data.zroot}}/var
    - target: {{data['var-directory'] }}
    - watch:
       - file: var-dirs-{{cfg.name}}

{% if not data.get('skip_eggs_cache', False) %}
# unpack the generic installer eggs cache to speed up installations
{{cfg.name}}-wgetplone:
  cmd.run:
    - name: |
            set -e
            set -x
            plone_ver="$(grep dist.plone.org/release "{{cfg.project_root}}/etc/base.cfg"|grep -v ".cfg"|{{data.link_selector_mode}} -n1|sed -re "s/.*dist.plone.org\/release\/(([0-9]+\.?){1,3})/\1/g")"
            plone_major="$(echo "${plone_ver}"|sed -re "s/^([0-9]+\.[0-9]+).*/\1/g")"
            wget -c "{{data.installer_url}}" -O "{{data.plone_arc}}${plone_ver}"
            touch "skip_plone_download${plone_ver}"
    - unless: |
              plone_ver="$(grep dist.plone.org/release "{{cfg.project_root}}/etc/base.cfg"|{{data.link_selector_mode}} -n1|sed -re "s/.*dist.plone.org\/release\/(([0-9]+\.?){1,3})/\1/g")"
              test -e "skip_plone_download${plone_ver}" && test -e "{{data.plone_arc}}${plone_ver}"
    - cwd: {{data.ui}}
    - user: {{cfg.user}}
    - require:
      - file: var-dirs-{{cfg.name}}

{{cfg.name}}-unpackplone:
  cmd.run:
    - name: |
            plone_ver="$(grep dist.plone.org/release "{{cfg.project_root}}/etc/base.cfg"|grep -v ".cfg"|{{data.link_selector_mode}} -n1|sed -re "s/.*dist.plone.org\/release\/(([0-9]+\.?){1,3})/\1/g")"
            tar xzvf {{data.plone_arc}}${plone_ver} && touch skip_plone_unpack${plone_ver}
    - unless: |
              plone_ver="$(grep dist.plone.org/release "{{cfg.project_root}}/etc/base.cfg"|grep -v ".cfg"|{{data.link_selector_mode}} -n1|sed -re "s/.*dist.plone.org\/release\/(([0-9]+\.?){1,3})/\1/g")"
              test -e skip_plone_unpack${plone_ver} && test -e "{{data.ui}}/Plone-${plone_ver}-UnifiedInstaller/install.sh"
    - cwd: {{data.ui}}
    - user: {{cfg.user}}
    - require:
      - cmd: {{cfg.name}}-wgetplone

{{cfg.name}}-unpackcache:
  cmd.run:
    - name: |
            plone_ver="$(grep dist.plone.org/release "{{cfg.project_root}}/etc/base.cfg"|grep -v ".cfg"|{{data.link_selector_mode}} -n1|sed -re "s/.*dist.plone.org\/release\/(([0-9]+\.?){1,3})/\1/g")"
            tar xjf "{{data.ui}}/Plone-${plone_ver}-UnifiedInstaller/packages/buildout-cache.tar.bz2"
    - unless: test -e {{data.buildout.settings.buildout['eggs-directory']}}/Products.CMFCore*
    - cwd: {{data.buildout.settings.buildout['cache-directory']}}/..
    - user: {{cfg.user}}
    - require:
      - cmd: {{cfg.name}}-unpackplone
{% endif %}

{{cfg.name}}-front-doc-root:
  cmd.run:
    - name: |
            if [ -e "{{cfg.project_root}}/dist/" ]; then
                rsync -Aa --delete "{{cfg.project_root}}/dist/" "{{data.front_doc_root}}/"
                if [ -e "{{cfg.project_root}}/angular/robots.txt" ];then
                  cp "{{cfg.project_root}}/angular/robots.txt" "{{data.front_doc_root}}/"
                fi
            fi
    - user: root
