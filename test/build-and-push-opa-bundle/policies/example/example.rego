package example

import rego.v1

default allow := false

# METADATA
# title: Allow admins
# description: Allows the request when the requesting user has the "admin" role.
# scope: document
# entrypoint: true
# schemas:
#   - input: schema["input-schema"]
allow if {
	input.user.role == "admin"
}
