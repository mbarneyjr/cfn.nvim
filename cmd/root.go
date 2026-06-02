package cmd

import (
	"os"

	"github.com/spf13/cobra"
)

var (
	profile string
	region  string
)

var rootCmd = &cobra.Command{
	Use:          "cfn-nvim",
	Short:        "cfn.nvim helper",
	Long:         "The helper CLI tool for the cfn.nvim plugin",
	SilenceUsage: true,
}

func init() {
	rootCmd.PersistentFlags().StringVar(&profile, "profile", "", "AWS profile to use")
	rootCmd.PersistentFlags().StringVar(&region, "region", "", "AWS region")
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}
