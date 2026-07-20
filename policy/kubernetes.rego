package main

import rego.v1

# Conftest policies for rendered Helm manifests (helm template | conftest test -).
# Enforces the hardening the chart claims. A violation fails CI (the policy gate).

deny contains msg if {
	input.kind == "Deployment"
	c := input.spec.template.spec.containers[_]
	not c.resources.limits
	msg := sprintf("container %q has no resource limits", [c.name])
}

deny contains msg if {
	input.kind == "Deployment"
	c := input.spec.template.spec.containers[_]
	not c.securityContext.allowPrivilegeEscalation == false
	msg := sprintf("container %q must set allowPrivilegeEscalation: false", [c.name])
}

deny contains msg if {
	input.kind == "Deployment"
	not input.spec.template.spec.securityContext.runAsNonRoot == true
	msg := "pod must set securityContext.runAsNonRoot: true"
}

deny contains msg if {
	input.kind == "Deployment"
	c := input.spec.template.spec.containers[_]
	not c.readinessProbe
	msg := sprintf("container %q must define a readinessProbe", [c.name])
}

deny contains msg if {
	input.kind == "Deployment"
	c := input.spec.template.spec.containers[_]
	not c.livenessProbe
	msg := sprintf("container %q must define a livenessProbe", [c.name])
}

# No plaintext secret-looking env values inline (must use secretKeyRef).
deny contains msg if {
	input.kind == "Deployment"
	c := input.spec.template.spec.containers[_]
	e := c.env[_]
	upper(e.name) == "N8N_ENCRYPTION_KEY"
	e.value
	msg := "N8N_ENCRYPTION_KEY must come from secretKeyRef, not an inline value"
}
