## Configure AKS cluster - This module is to specific to Common Platform
The module is used to configure AKS cluster for common platform.

### OAuth Istio ingress

The OAuth ingress uses `istio_ingress_oauth_domains` for its dedicated namespace, Istio ingress release, TLS Certificate, Gateway and internal LoadBalancer Service. The default `istio_components_hpa_spec` map sets OAuth replica bounds to a minimum of 2 and a maximum of 10. Environment maps replace the default map and must include `istio_ingress_oauth_min_replicas` and `istio_ingress_oauth_max_replicas`. The module exports `ingress_lb_private_ip_address_oauth` for DNS configuration.

When `istio_ingress_oauth_health_hostname` is set, a VirtualService on the OAuth Gateway routes `https://<hostname>/healthz/ready` on port 443 to the gateway's Istio status port `15021`. The hostname must be covered by `istio_ingress_oauth_domains`.

#### OAuth JWT policies

The OAuth gateway has dedicated `RequestAuthentication` and `AuthorizationPolicy` resources. Supply these required, nonsecret strings:

| Input | Value |
|---|---|
| `istio_ingress_oauth_jwt_issuer` | Exact issuer from the matching Entra OpenID Connect metadata and token `iss` claim |
| `istio_ingress_oauth_jwt_jwks_uri` | HTTPS `jwks_uri` from that same metadata document |

Null, empty, whitespace-only and `REPLACE_ME` placeholder values are rejected. Do not store or share access tokens. The original `Authorization: Bearer` token is forwarded; applications retain their own authorization checks.

The gateway deliberately has no audience restriction for initial testing. It validates signature, exact issuer and token time claims, but accepts any audience from that issuer. This may admit ID tokens or tokens intended for unrelated resources. Every protected service must validate its own audience, token type and roles/scopes. Gateway acceptance alone does not authorize access to a service.

Only the OAuth workload is selected. API requests require an authenticated principal. A separate rule permits tokenless `GET /healthz/ready` only on the exact configured health hostname. It does not identify the caller. Wildcard health hosts are rejected. Setting the health hostname to null omits both the health route and its permission. Invalid supplied JWTs are still rejected, including on the health endpoint.

Before rollout, review the rendered policies and all other policies that select this gateway. Verify Istiod can retrieve the public signing keys over the existing HTTPS outbound path. No credential or network rule is added.

For nonlive runtime tests, use an approved token without printing or recording it. Verify a valid token reaches the test backend; missing, expired, wrong-issuer and invalid-signature tokens do not. A valid token for a different audience may pass the gateway; verify the destination service rejects an inappropriate audience or token type. Verify the original token is forwarded with approved local tooling that does not log it. Verify a tokenless exact health GET returns 200, while an API host using that path, a different path, or a different method does not use the exception. Test host/path variants and confirm they cannot route tokenless traffic to an API.

To revert, first stop or reroute protected traffic away from the OAuth gateway. Restore the previous reviewed configuration through Terraform, then verify the route and health state. Never remove enforcement while protected API traffic still uses this gateway. Restoring a previous version without these policies does not preserve JWT protection.

### Note
There wont be any tests in this repo. This module is an exception because its not possible to implement tests here and the tests are written in the root module which have an pipeline option to run the tests on clusters which are created as part of it.
