package kubernetes.admission

import data.kubernetes.namespaces

operations = {"CREATE", "UPDATE"}

deny contains msg if {
    input.request.kind.kind == "Ingress"
    operations[input.request.operation]
    host := input.request.object.spec.rules[_].host
    not fqdn_matches_any(host, valid_ingress_hosts)
    msg := sprintf("invalid ingress host %q", [host])
}

valid_ingress_hosts = {host |
    allowlist := namespaces[input.request.namespace].metadata.annotations["ingress-allowlist"]
    hosts := split(allowlist, ",")
    host := hosts[_]
}

fqdn_matches_any(str, patterns) if {
    fqdn_matches(str, patterns[_])
}

fqdn_matches(str, pattern) if {
    pattern_parts := split(pattern, ".")
    pattern_parts[0] == "*"
    str_parts := split(str, ".")
    n_pattern_parts := count(pattern_parts)
    n_str_parts := count(str_parts)
    suffix := trim(pattern, "*.")
    endswith(str, suffix)
}

fqdn_matches(str, pattern) if {
    not contains(pattern, "*")
    str == pattern
}