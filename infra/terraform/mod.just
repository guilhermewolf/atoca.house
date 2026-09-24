set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

terraform_dir := justfile_dir() + '/infra/terraform'
pg_namespace := 'crunchy-postgres-cluster'
pg_secret := 'postgres-pguser-terraform'
pg_local_port := '15432'
op_item := 'op://K8s/opentofu-secrets'

[private]
default:
    just -l tofu

[doc('Run tofu plan (port-forwards the pg backend, secrets from 1Password)')]
plan *args:
    just tofu run plan {{ args }}

[doc('Run tofu apply (port-forwards the pg backend, secrets from 1Password)')]
apply *args:
    just tofu run apply {{ args }}

[doc('Run any tofu command with backend + secrets wired up')]
run +args:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ terraform_dir }}"

    secret() { kubectl -n {{ pg_namespace }} get secret {{ pg_secret }} -o jsonpath="{.data.$1}" | base64 -d; }
    pg_user=$(secret user); pg_pass=$(secret password); pg_db=$(secret dbname)

    kubectl -n {{ pg_namespace }} port-forward svc/postgres-pgbouncer {{ pg_local_port }}:5432 >/dev/null 2>&1 &
    pf_pid=$!
    trap 'kill $pf_pid 2>/dev/null || true' EXIT INT TERM
    for _ in $(seq 1 20); do nc -z 127.0.0.1 {{ pg_local_port }} 2>/dev/null && break; sleep 0.5; done
    nc -z 127.0.0.1 {{ pg_local_port }} || { echo "port-forward to pgbouncer failed" >&2; exit 1; }

    export PG_CONN_STR="postgres://${pg_user}:$(jq -rn --arg p "$pg_pass" '$p|@uri')@127.0.0.1:{{ pg_local_port }}/${pg_db}?sslmode=require"
    export TF_VAR_cloudflare_api_token="{{ op_item }}/TF_VAR_CLOUDFLARE_API_TOKEN"
    export TF_VAR_zone_id="{{ op_item }}/TF_VAR_ZONE_ID"
    export TF_VAR_account_id="{{ op_item }}/TF_VAR_ACCOUNT_ID"
    export TF_VAR_domain="{{ op_item }}/TF_VAR_DOMAIN"
    export TF_VAR_npm_ip="{{ op_item }}/TF_VAR_NPM_IP"
    export TF_VAR_unifi_api_url="{{ op_item }}/TF_VAR_UNIFI_API_URL"
    export TF_VAR_unifi_api_key="{{ op_item }}/TF_VAR_UNIFI_API_KEY"

    [ -d .terraform ] || op run -- tofu init
    op run -- tofu {{ args }}
