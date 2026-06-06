package cmd

import (
	"encoding/json"
	"fmt"
	"os"

	aws_lib "github.com/mbarneyjr/cfn.nvim/internal/aws"
	jwe_lib "github.com/mbarneyjr/cfn.nvim/internal/jwe"
	profile_lib "github.com/mbarneyjr/cfn.nvim/internal/profile"
	"github.com/spf13/cobra"
)

var profileCmd = &cobra.Command{
	Use:   "profile",
	Short: "Manage AWS profile selection",
}

type listResponse struct {
	Profiles []string `json:"profiles"`
}

var profileListCmd = &cobra.Command{
	Use:   "list",
	Short: "List configured AWS profiles",
	RunE: func(cmd *cobra.Command, args []string) error {
		profiles, err := profile_lib.ListProfiles()
		if err != nil {
			return fmt.Errorf("failed to list profiles: %w", err)
		}
		result, err := json.Marshal(listResponse{
			Profiles: profiles,
		})
		if err != nil {
			return fmt.Errorf("failed to marshal: %w", err)
		}
		os.Stdout.Write(result)
		return nil
	},
}

// argument: the encryption key to use to encrypt the jwk
var profileCredentialsKey string

type credentialsResponse struct {
	Jwe         string `json:"jwe"`
	Region      string `json:"region"`
	AccountId   string `json:"accountId"`
	Expiry      string `json:"expiry,omitempty"`
	ExpiryEpoch int64  `json:"expiryEpoch,omitempty"`
}

var profileCredentialsCmd = &cobra.Command{
	Use:   "credentials",
	Short: "Export and JWE-encrypt the profile credentials for the LSP",
	RunE: func(cmd *cobra.Command, args []string) error {
		resolved, err := aws_lib.Resolve(cmd.Context(), profile, region)
		if err != nil {
			return err
		}
		payload, err := json.Marshal(map[string]any{
			"data": map[string]any{
				"profile":         profile,
				"accessKeyId":     resolved.AccessKeyId,
				"secretAccessKey": resolved.SecretAccessKey,
				"sessionToken":    resolved.SessionToken,
				"region":          resolved.Region,
			},
		})
		if err != nil {
			return fmt.Errorf("failed to marshal credentials payload: %w", err)
		}

		token, err := jwe_lib.Encrypt(payload, profileCredentialsKey)
		if err != nil {
			return fmt.Errorf("failed to encrypt credentials: %w", err)
		}
		result, err := json.Marshal(credentialsResponse{
			Jwe:         token,
			Region:      resolved.Region,
			AccountId:   resolved.AccountId,
			Expiry:      resolved.Expiry,
			ExpiryEpoch: resolved.ExpiryEpoch,
		})
		if err != nil {
			return fmt.Errorf("failed to marshal: %w", err)
		}
		os.Stdout.Write(result)
		return nil
	},
}

func init() {
	profileCredentialsCmd.Flags().StringVar(&profileCredentialsKey, "key", "", "JWK to encrypt the credentials with")
	_ = profileCredentialsCmd.MarkFlagRequired("key")

	profileCmd.AddCommand(profileListCmd)
	profileCmd.AddCommand(profileCredentialsCmd)

	rootCmd.AddCommand(profileCmd)
}
