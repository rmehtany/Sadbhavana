package html

import (
	"bytes"
	"context"
	"fmt"

	"github.com/a-h/templ"
)

type HTMLResponse struct {
	Body        []byte
	ContentType string
}

func CreateHTMLResponse(ctx context.Context, component templ.Component) (*HTMLResponse, error) {
	htmlBytes, err := renderTemplToBytes(ctx, component)
	if err != nil {
		return nil, fmt.Errorf("failed to render template: %w", err)
	}

	return &HTMLResponse{
		ContentType: "text/html; charset=utf-8",
		Body:        htmlBytes,
	}, nil
}

func renderTemplToBytes(ctx context.Context, component templ.Component) ([]byte, error) {
	var buf bytes.Buffer

	err := component.Render(ctx, &buf)
	if err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}
