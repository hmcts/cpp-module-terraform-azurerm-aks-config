## Configure AKS cluster - This module is to specific to Common Platform
The module is used to configure AKS cluster for common platform.

### Apps, management and web ingress health checks

The optional `istio_ingress_apps_health_hostname`, `istio_ingress_mgmt_health_hostname` and `istio_ingress_web_health_hostname` inputs default to null. Set an input to an exact hostname to create a VirtualService for that gateway. It routes `https://<hostname>/healthz/ready` on port 443 to the gateway Service's Istio status port `15021`. Leave it null to omit the route.

The hostname must match the corresponding `istio_ingress_apps_domains`, `istio_ingress_mgmt_domains` or `istio_ingress_web_domains` Gateway host and be covered by its TLS certificate. Configure the Application Gateway HTTPS probe with that hostname and path. The management gateway's existing IP-based authorization policy still applies; allow the probe's source as appropriate. Confirm the probe succeeds in the target environment before relying on it.

### OAuth Istio ingress

The OAuth ingress is disabled by default. Set `enable_istio_oauth = true` to deploy its dedicated namespace, Istio ingress release, TLS Certificate, Gateway, optional health route, internal LoadBalancer Service and JWT policies. When disabled, the module creates none of these resources, does not query the OAuth Service, and returns null for `ingress_lb_private_ip_address_oauth`. Existing apps, management and web ingress resources remain enabled.

When enabled, supply a non-empty `istio_ingress_oauth_domains` list and the JWT inputs below. OAuth replica bounds default to 2 and 10 even when an existing environment supplies an HPA map without OAuth keys. Set `istio_ingress_oauth_min_replicas` and `istio_ingress_oauth_max_replicas` in that map to override these bounds.

Merge this module's feature-flag changes to `main` before merging a caller that passes `enable_istio_oauth`. Terraform checks module arguments even when the flag is false. Callers must use a static module source; a feature flag cannot select a source reference.

When `istio_ingress_oauth_health_hostname` is set, a VirtualService on the OAuth Gateway routes `https://<hostname>/healthz/ready` on port 443 to the gateway's Istio status port `15021`. The hostname must be covered by `istio_ingress_oauth_domains`.

#### OAuth JWT policies

The OAuth gateway has dedicated `RequestAuthentication` and `AuthorizationPolicy` resources. When enabled, supply these required, nonsecret strings:

| Input | Value |
|---|---|
| `istio_ingress_oauth_jwt_issuer` | Exact issuer from the matching Entra OpenID Connect metadata and token `iss` claim |
| `istio_ingress_oauth_jwt_jwks_uri` | HTTPS `jwks_uri` from that same metadata document |

The JWT inputs default to empty strings so existing callers need no new settings. Enabling OAuth without both inputs blocks the plan. Whitespace-only values and non-HTTPS JWKS URIs are rejected. Do not store or share access tokens. The original `Authorization: Bearer` token is forwarded; applications retain their own authorization checks.

The gateway deliberately has no audience restriction for initial testing. It validates signature, exact issuer and token time claims, but accepts any audience from that issuer. This may admit ID tokens or tokens intended for unrelated resources. Every protected service must validate its own audience, token type and roles/scopes. Gateway acceptance alone does not authorize access to a service.

Only the OAuth workload is selected. API requests require an authenticated principal. A separate rule permits tokenless `GET /healthz/ready` only on the exact configured health hostname. It does not identify the caller. Wildcard health hosts are rejected. Setting the health hostname to null omits both the health route and its permission. Invalid supplied JWTs are still rejected, including on the health endpoint.

Before rollout, review the rendered policies and all other policies that select this gateway. Verify Istiod can retrieve the public signing keys over the existing HTTPS outbound path. No credential or network rule is added.

For nonlive runtime tests, use an approved token without printing or recording it. Verify a valid token reaches the test backend; missing, expired, wrong-issuer and invalid-signature tokens do not. A valid token for a different audience may pass the gateway; verify the destination service rejects an inappropriate audience or token type. Verify the original token is forwarded with approved local tooling that does not log it. Verify a tokenless exact health GET returns 200, while an API host using that path, a different path, or a different method does not use the exception. Test host/path variants and confirm they cannot route tokenless traffic to an API.

To revert, first stop or reroute protected traffic away from the OAuth gateway. Setting `enable_istio_oauth = false` removes the gateway and its related resources; it does not merely disable JWT checks. Verify the plan and route state before applying. Never remove enforcement while protected API traffic still uses this gateway. No state migration is provided for existing OAuth resources. Adopting the feature flag can recreate the OAuth namespace, Helm release and wait resource, with service interruption. Any environment that already deployed this branch must explicitly enable the flag before its next apply to keep OAuth enabled.

### Note
There wont be any tests in this repo. This module is an exception because its not possible to implement tests here and the tests are written in the root module which have an pipeline option to run the tests on clusters which are created as part of it.
