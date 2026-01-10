package cli

import (
	"log"
	"os"

	urfave "github.com/urfave/cli/v2"
)

// RunCLI starts the CLI application. Currently it provides a single
// noop command for testing and placeholder usage.
func RunCLI() {
	app := &urfave.App{
		Name:  "tree-project",
		Usage: "Utilities for the Tree Map project",
		Commands: []*urfave.Command{
			{
				Name:        "integration",
				Usage:       "Commands for managing integrations",
				Aliases:     []string{"int", "i"},
				Subcommands: []*urfave.Command{},
			},
		},
	}

	if err := app.Run(os.Args); err != nil {
		log.Fatal(err)
	}
}
