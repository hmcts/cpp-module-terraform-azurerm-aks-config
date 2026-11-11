## Unreleased

- Make the entire OAuth ingress opt-in with `enable_istio_oauth = false` by default, optional JWT inputs and HPA fallbacks for existing environment maps.
- Allow existing OAuth resources to be recreated when adopting the feature flag; no state migration is provided.
- Add OAuth gateway JWT validation and authenticated-principal enforcement.
- Permit only the configured health hostname's exact `GET /healthz/ready` without a token.
- Require issuer and HTTPS JWKS URI when OAuth is enabled.
- Omit gateway audience restrictions for initial testing; services retain audience, token-type and permission checks.
- Stop `store_azure_info` showing a diff in every plan: build the `azure-info` template from plan-time values instead of managed resource attributes.

## [v1.28.3](https://github.com/hmcts/cpp-module-terraform-azurerm-aks-config/commit/b336a3baaca96ab94e9f06f3ae27e315d6758507) (2024-08-02)

### CHANGES

- Created a new tag v1.28.3 to be used by environments still running Kubernetes 1.28.3.
- Clusters on v1.30.3 (latest as of now) will need to source from the `main` branch.
