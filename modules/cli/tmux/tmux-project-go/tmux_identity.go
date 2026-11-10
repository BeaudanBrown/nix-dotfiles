package main

import (
	"regexp"
	"strconv"
	"strings"
)

// Presentation targets only. These never authorize launching/terminating Pi;
// native file locks own that decision.
type exactTmux func(...string) (string, error)

var exactWindowPattern = regexp.MustCompile(`^@[0-9]{1,20}$`)
var exactPanePattern = regexp.MustCompile(`^%[0-9]{1,20}$`)
var exactPIDPattern = regexp.MustCompile(`^[1-9][0-9]{0,19}$`)

func exactPID(value string) bool {
	pid, err := strconv.ParseUint(value, 10, 31)
	return err == nil && pid > 0 && exactPIDPattern.MatchString(value)
}
func validClientName(name string) bool {
	return name != "" && len(name) <= 256 && !strings.ContainsAny(name, "#{},") && strings.IndexFunc(name, func(r rune) bool { return r < 0x20 || r == 0x7f }) < 0
}
func formatAnd(parts ...string) string {
	result := "1"
	for _, part := range parts {
		result = "#{&&:" + result + "," + part + "}"
	}
	return result
}
func formatEqual(field, value string) string { return "#{==:#{" + field + "}," + value + "}" }
