package main

import (
	"strings"
	"time"

	"github.com/dlclark/regexp2"
)

type resourceFilter struct {
	Label   string
	Pattern string
	parts   []*regexp2.Regexp
}

func compileResourceFilter(value string) ([]*regexp2.Regexp, error) {
	parts := []*regexp2.Regexp{}
	for _, part := range strings.Split(value, "`") {
		expression, err := regexp2.Compile(part, regexp2.None)
		if err != nil {
			return nil, err
		}
		expression.MatchTimeout = 50 * time.Millisecond
		parts = append(parts, expression)
	}
	return parts, nil
}

func validateResourceFilters(values []string) ([]string, error) {
	if len(values) > 128 {
		return nil, failure("invalid_request")
	}
	results := make([]string, len(values))
	for i, value := range values {
		if len(value) > 4096 || strings.ContainsAny(value, "\x00\r\n") {
			return nil, failure("invalid_request")
		}
		if _, err := compileResourceFilter(value); err != nil {
			results[i] = err.Error()
		}
	}
	return results, nil
}

func resourceFilters(value any) ([]resourceFilter, error) {
	result := []resourceFilter{}
	if value == nil {
		return result, nil
	}
	items, ok := value.([]any)
	if !ok || len(items) > 128 {
		return nil, failure("invalid_request")
	}
	seen := map[string]bool{}
	for _, item := range items {
		entry, ok := item.(map[string]any)
		if !ok || len(entry) != 2 {
			return nil, failure("invalid_request")
		}
		label, labelOK := entry["label"].(string)
		pattern, patternOK := entry["regex"].(string)
		if !labelOK || !patternOK || strings.TrimSpace(label) == "" || strings.TrimSpace(pattern) == "" || len(label) > 256 || len(pattern) > 4096 || strings.ContainsAny(label+pattern, "\x00\r\n") || seen[label] {
			return nil, failure("invalid_request")
		}
		seen[label] = true
		parts, err := compileResourceFilter(pattern)
		if err != nil {
			return nil, failure("invalid_request")
		}
		result = append(result, resourceFilter{Label: label, Pattern: pattern, parts: parts})
	}
	return result, nil
}

func (filter resourceFilter) matches(value string) (bool, error) {
	for _, part := range filter.parts {
		matched, err := part.MatchString(value)
		if err != nil || matched {
			return matched, err
		}
	}
	return false, nil
}
