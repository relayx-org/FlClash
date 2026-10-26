package probe

import (
	"bytes"
	"io"
)

const (
	probeScanChunk   = 32 * 1024
	probeScanOverlap = 256
)

func ReadBody(body io.Reader, maxBody int64, until func(string) bool) string {
	limited := io.LimitReader(body, maxBody)
	if until == nil {
		payload, _ := io.ReadAll(limited)
		return string(payload)
	}
	var buffer bytes.Buffer
	chunk := make([]byte, probeScanChunk)
	for {
		n, err := limited.Read(chunk)
		if n > 0 {
			start := max(0, buffer.Len()-probeScanOverlap)
			buffer.Write(chunk[:n])
			if until(string(buffer.Bytes()[start:])) {
				break
			}
		}
		if err != nil {
			break
		}
	}
	return buffer.String()
}
