This project provides containerized X-Road components that can be deployed using Docker Compose or LXD for development, testing, and learning purposes.

## Architecture Overview

This environment includes a complete X-Road ecosystem with the following components:

- **Central Server (CS)** - Manages global configuration and member registration
- **Security Servers (SS0, SS1)** - Handle secure message exchange between organizations
- **Test CA** - Certificate Authority for development and testing
- **Information Systems** - Sample services for testing:
  - **ISSOAP** - SOAP web service example
  - **ISREST** - REST API service (Wiremock-based)
  - **ISOPENAPI** - OpenAPI 3.0 service example
- **Mailpit** - Email testing server
- **Hurl** - API testing framework

### Option 1: Docker Compose (Recommended)

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd k8s-xroad
   ```

2. **Start the environment:**
   ```bash
   cd Docker/xrd-dev-stack
   ./local-dev-run.sh --initialize
   ```

3. **Access the services:**
   - Central Server UI: https://localhost:4100
   - Security Server SS0 UI: https://localhost:4200
   - Security Server SS1 UI: https://localhost:4300
   - Test CA: http://localhost:4400
   - Mailpit: http://localhost:8025

### Option 2: Local Development Build

If you want to build from local X-Road source code:

```bash
cd Docker/xrd-dev-stack
./local-dev-prepare.sh
./local-dev-run.sh --initialize --local
```

### Option 3: LXD Environment

For native LXD deployment:

**macOS:**
```bash
cd development/native-lxd-stack
./scripts/setup-mac.sh
./start-env.sh
```

**Linux:**
```bash
cd development/native-lxd-stack
./scripts/setup-lxc.sh
./start-env.sh
```

## Available Services

| Service | Description | Port (Dev) | URL |
|---------|-------------|------------|-----|
| Central Server | X-Road central management | 4100 | https://localhost:4100 |
| Security Server SS0 | Management & Producer SS | 4200 | https://localhost:4200 |
| Security Server SS1 | Consumer SS | 4300 | https://localhost:4300 |
| Test CA | Certificate Authority | 4400 | http://localhost:4400 |
| ISREST | REST API Service | 4500 | http://localhost:4500 |
| ISSOAP | SOAP Service | 4600 | http://localhost:4600 |
| ISOPENAPI | OpenAPI Service | 4700 | http://localhost:4700 |
| Mailpit | Email Testing | 8025 | http://localhost:8025 |

## Configuration

### Environment Variables

The environment uses the following key variables:

```bash
# Service hosts
cs_host=cs
ss0_host=ss0
ss1_host=ss1
ca_host=testca

# Service URLs
example_service_wsdl=http://issoap:8080/example-adapter/Endpoint?wsdl
example_service_address=http://issoap:8080/example-adapter/Endpoint
is_rest_url=http://isrest:8080/integration/mock_1
is_openapi_url=http://isopenapi:8080/v3/api-docs
```

### Default Credentials

- **Username:** `xrd`
- **Password:** `secret`
- **Token PIN:** `Secret1234`

## Testing

The environment includes comprehensive testing capabilities:

### API Testing with Hurl

```bash
# Run setup tests
docker compose run --rm hurl --insecure --variables-file /hurl-src/vars.env /hurl-src/setup.hurl

# Run performance tests
docker compose run --rm hurl --insecure --variables-file /hurl-src/vars.env /hurl-src/perftest-ss0.hurl
```

### Available Test Scenarios

- `setup.hurl` - Complete environment initialization
- `single-ss.hurl` - Single security server tests
- `test-proxy-rest.hurl` - REST API proxy tests
- `test-proxy-soap.hurl` - SOAP API proxy tests
- `perftest-ss0.hurl` - Performance testing

## Monitoring and Debugging

### Debug Ports

| Service | Debug Ports | Description |
|---------|-------------|-------------|
| CS | 4190-4194 | Admin, Management, Registration, Conf Client, Signer |
| SS0 | 4290-4293 | Proxy, Signer, Proxy UI, Conf Client |
| SS1 | 4390-4393 | Proxy, Signer, Proxy UI, Conf Client |

### Logs

```bash
# View all logs
docker compose logs -f

# View specific service logs
docker compose logs -f cs
docker compose logs -f ss0
docker compose logs -f ss1
```