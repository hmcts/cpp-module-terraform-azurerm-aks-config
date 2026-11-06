## Unreleased

- Add OAuth gateway JWT validation and authenticated-principal enforcement.
- Permit only the configured health hostname's exact `GET /healthz/ready` without a token.
- Require issuer and HTTPS JWKS URI; reject review placeholders before deployment.
- Omit gateway audience restrictions for initial testing; services retain audience, token-type and permission checks.

## [v1.28.3](https://github.com/hmcts/cpp-module-terraform-azurerm-aks-config/commit/b336a3baaca96ab94e9f06f3ae27e315d6758507) (2024-08-02)

### CHANGES

- Created a new tag v1.28.3 to be used by environments still running Kubernetes 1.28.3.
- Clusters on v1.30.3 (latest as of now) will need to source from the `main` branch.
