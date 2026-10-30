## Configure AKS cluster - This module is to specific to Common Platform
The module is used to configure AKS cluster for common platform.

### OAuth Istio ingress

The OAuth ingress uses `istio_ingress_oauth_domains` for its dedicated namespace, Istio ingress release, TLS Certificate, Gateway and internal LoadBalancer Service. The default `istio_components_hpa_spec` map sets OAuth replica bounds to a minimum of 2 and a maximum of 10. Environment maps replace the default map and must include `istio_ingress_oauth_min_replicas` and `istio_ingress_oauth_max_replicas`. The module exports `ingress_lb_private_ip_address_oauth` for DNS configuration.

### Note
There wont be any tests in this repo. This module is an exception because its not possible to implement tests here and the tests are written in the root module which have an pipeline option to run the tests on clusters which are created as part of it.
