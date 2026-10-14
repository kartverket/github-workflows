package example_test

import data.example
import rego.v1

test_allow_admin if {
	example.allow with input as {"user": {"role": "admin"}}
}

test_deny_non_admin if {
	not example.allow with input as {"user": {"role": "viewer"}}
}
