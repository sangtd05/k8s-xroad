# Using this Docker Compose environment

**NB!** The compose environment is meant only for testing X-Road in a development setup, it should never be used in a
production environment.

This document expects that you have a working Docker setup with Docker Compose installed on your system.
Setup was tested with Docker version `24.x` and Docker Compose version `2.24.x`.
There is no guarantees that this environment will work with older versions.

The environment is set up by default to be used with the `xrddev-*` images available from the
[main X-Road repository](https://github.com/orgs/nordic-institute/packages?repo_name=X-Road).

The Compose environment also contains a Hurl container and scripts to initialize an environment. Stack consists of:

* **CS**: Central Server
* **SS0** One management Security Server, which also acts as the producer Security Server for the example adapter under the
  `DEV:COM:1234:TestService` subsystem. Permissions are given to the `DEV:COM:4321:TestClient` subsystem to access all
  requests under it.
* **SS1** One consumer Security Server, which has the `DEV:COM:4321:TestClient` subsystem registered to it.
* **ISSOAP** The `example-adapter` container. More information regarding it is available in
  [its own repository](https://github.com/nordic-institute/xrd4j/tree/develop/example-adapter).
* **ISOPENAPI** The `example-restapi` container. More information regarding it is available in
  [its own repository](https://github.com/nordic-institute/x-road-example-restapi).
* **ISREST** Wiremock container with a simple predefined rest endpoint.
* **TESTCA** CA authority for dev env.

The default compose file does not forward any ports to the host system, but dev profile does provide extensive list of ports.
See: [compose.dev.yaml](compose.dev.yaml) for details

Please note that the containers do not have any persistent volume mappings, so once they are removed, all data is also
lost.

## Settings up environment from remote images

### Prerequisites:

* Optionally set the `XROAD_HOME` environment variable in your shell profile. This variable should point to the root
  directory of the X-Road source code. This is needed for the scripts to find the correct files if the shell script is
  executed from a different working directory.

### Creating the environment

To start the containers, use provided script:

```bash
./local-dev-run.sh --initialize
```

Initialising the environment will take a few minutes, and there will be several points where it will get HTTP errors
and keep retrying. This is normal and is due to the time it takes for the global configuration updates to happen and be
distributed to the Security Servers.

The command should finish with last hurl request being successful.

NOTE: Refer to provided bash files for additional customization options.

## Setting up an environment based on your own local code

You can also build the X-Road source code and use the resulting packages to deploy the containers. Use the following commands:

```bash
./local-dev-prepare.sh
./local-dev-run.sh --initialize --local
```

This step expects that you are able to build and package the X-Road source code.

This script will do the following:

* Build the source code with Gradle
  * Type `./local-dev-prepare.sh -h` for complete list of usage arguments. For example:
    * `--skip-gradle-build` to skip gradle build
    * `--skip-tests` to skip tests
    * `--parallel` to run gradle build in parallel
    * `-r release-name` for a specific release only
* Build Ubuntu Jammy packages in Docker
* Copy the resulting Debian packages to their correct locations
* Build the `centralserver`, `securityserver` and `testca` Docker images
* Start the Docker Compose environment

## Multi-host deployment (split SS1 on another machine)

This repository includes example compose files to run CS/SS0/services (Site A) and SS1 (Site B) on separate hosts.

### 1) Networking prerequisites

- Ensure Site A and Site B can reach each other via IP/DNS and that firewalls allow the following inbound ports:
  - Site A: `4100` (CS UI), `4200` (SS0 UI), `4210` (SS0 Proxy), plus sample services `4500/4600/4700` if used
  - Site B: `4300` (SS1 UI), `4310` (SS1 Proxy)
- Optionally create DNS records (e.g. `cs.local`, `ss0.local`, `ss1.local`) or update hosts files accordingly on both machines.

### 2) Bring up Site A (CS, SS0, Services)

On Site A host, from this directory:

```bash
docker compose -f compose.site-a.yaml up -d
```

Environment variables (optional):

```bash
export XROAD_TOKEN_PIN=Secret1234
export CS_IMG=niis/xroad-centralserver:latest
export SS_IMG=niis/xroad-security-server:latest
export CA_IMG=... # testca image
export IS_OPENAPI_IMG=... # example rest api image
export IS_SOAP_IMG=...    # example soap adapter image
```

### 3) Bring up Site B (SS1)

On Site B host:

```bash
docker compose -f compose.site-b.yaml up -d
```

Optionally set:

```bash
export XROAD_TOKEN_PIN=Secret1234
export SS_IMG=niis/xroad-security-server:latest
```

### 4) Configure cross-host names for tests

The Hurl container on Site A uses `development/hurl/scenarios/vars.multi-host.env` which supports overriding hostnames.
Export these on Site A before running init/tests to point to resolvable names/IPs across hosts:

```bash
export CS_HOST=<site-a-cs-host-or-ip>
export SS0_HOST=<site-a-ss0-host-or-ip>
export TESTCA_HOST=<site-a-testca-host-or-ip>
export ISSOAP_HOST=<site-a-issoap-host-or-ip>
export ISOPENAPI_HOST=<site-a-isopenapi-host-or-ip>
export ISREST_HOST=<site-a-isrest-host-or-ip>
export SS1_HOST=<site-b-ss1-host-or-ip>
```

Hurl is wired via `compose.site-a.yaml` to load that vars file. If you run Hurl manually in the container, pass:

```bash
docker exec -it hurl env HURL_VARS_FILE=/hurl-files/scenarios/vars.multi-host.env hurl --variable-file /hurl-files/scenarios/vars.multi-host.env /hurl-files/scenarios/setup.hurl
```

### 5) X-Road configuration considerations

- When SS1 runs on Site B, it will fetch global configuration from CS on Site A. Ensure Site B can reach Site A `cs_host` and `ss0_host` where needed.
- Admin UIs are available on:
  - Site A: CS `https://<site-a>:4100`, SS0 `https://<site-a>:4200`
  - Site B: SS1 `https://<site-b>:4300`
- Certificates and trust anchors are exchanged as usual; ensure clocks are in sync.

### 6) Troubleshooting

- Verify healthchecks: `docker ps` and `docker logs <service>` on both hosts.
- Test reachability between hosts (ping/curl the mapped ports) and firewall rules.
- If name resolution fails, use IPs in the env overrides.