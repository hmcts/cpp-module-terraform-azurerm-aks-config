## Configure AKS cluster - This module is to specific to Common Platform
The module is used to configure AKS cluster for common platform.

### OAuth Istio ingress

The OAuth ingress uses `istio_ingress_oauth_domains` for its dedicated namespace, Istio ingress release, TLS Certificate, Gateway, internal LoadBalancer Service and Private Link Service. It uses the apps ingress replica bounds from `istio_components_hpa_spec`. The module exports `ingress_lb_private_ip_address_oauth_apps` and `private_link_service_ingress_oauth_apps_id` for DNS configuration.

### Note
There wont be any tests in this repo. This module is an exception because its not possible to implement tests here and the tests are written in the root module which have an pipeline option to run the tests on clusters which are created as part of it.
