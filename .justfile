#!/usr/bin/env -S just --justfile

set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

mod bootstrap "bootstrap"
mod kube "infra/k8s"
mod talos "infra/talos"

[private]
default:
    just -l

[private]
log lvl msg *args:
    gum log -t rfc3339 -s -l "{{ lvl }}" "{{ msg }}" {{ args }}

[private]
template file *args:
    minijinja-cli "{{ file }}" {{ if env_var_or_default("IS_CONTROLLER", "") != "" { "-D IS_CONTROLLER=" + env_var("IS_CONTROLLER") } else { "" } }} {{ args }} | op inject
