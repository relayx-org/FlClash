package main

import (
	"strings"

	"github.com/dop251/goja"
)

type resourceScript struct{ ID, Label, Content string }

func resourceScripts(value any) ([]resourceScript, error) {
	entries, err := resourceEntries(value)
	if err != nil {
		return nil, err
	}
	result := []resourceScript{}
	names := map[string]bool{}
	total := 0
	for _, entry := range entries {
		label, ok := entry["label"].(string)
		content, contentOK := entry["content"].(string)
		if !ok || !contentOK || !resourceName(label) || len(content) > 131072 || strings.ContainsRune(content, 0) || names[label] || len(entry) < 3 || len(entry) > 4 {
			return nil, failure("invalid_request")
		}
		if address, exists := entry["url"]; exists {
			text, ok := address.(string)
			if !ok || text != "" && !validResourceURL(address) {
				return nil, failure("invalid_request")
			}
		} else if len(entry) != 3 {
			return nil, failure("invalid_request")
		}
		if _, err := goja.Compile("script", content, false); err != nil {
			return nil, failure("invalid_request")
		}
		total += len(content)
		if total > 1048576 {
			return nil, failure("invalid_request")
		}
		names[label] = true
		result = append(result, resourceScript{entry["id"].(string), label, content})
	}
	return result, nil
}

func validateResourceScripts(values []string) ([]string, error) {
	if len(values) > 128 {
		return nil, failure("invalid_request")
	}
	result := make([]string, len(values))
	for index, value := range values {
		if len(value) > 131072 || strings.ContainsRune(value, 0) {
			return nil, failure("invalid_request")
		}
		if _, err := goja.Compile("script", value, false); err != nil {
			result[index] = err.Error()
		}
	}
	return result, nil
}
