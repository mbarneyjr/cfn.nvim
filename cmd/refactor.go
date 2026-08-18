package cmd

import (
	"encoding/json"
	"fmt"
	"os"

	awssdk "github.com/aws/aws-sdk-go-v2/aws"
	aws_lib "github.com/mbarneyjr/cfn.nvim/internal/aws"
	"github.com/spf13/cobra"
)

var refactorCmd = &cobra.Command{
	Use:   "refactor",
	Short: "Manage CloudFormation stack refactors",
}

func writeJson(value any) error {
	result, err := json.Marshal(value)
	if err != nil {
		return fmt.Errorf("failed to marshal: %w", err)
	}
	os.Stdout.Write(result)
	return nil
}

type refactorIdResponse struct {
	StackRefactorId string `json:"stackRefactorId"`
}

var refactorCreatePayload string

var refactorCreateCmd = &cobra.Command{
	Use:   "create",
	Short: "Create a stack refactor, which can create stacks that do not exist yet",
	RunE: func(cmd *cobra.Command, args []string) error {
		var request aws_lib.RefactorRequest
		if err := json.Unmarshal([]byte(refactorCreatePayload), &request); err != nil {
			return fmt.Errorf("failed to parse payload: %w", err)
		}
		id, err := aws_lib.CreateStackRefactor(cmd.Context(), profile, region, request)
		if err != nil {
			return err
		}
		return writeJson(refactorIdResponse{StackRefactorId: id})
	},
}

var refactorId string

type refactorDescribeResponse struct {
	StackRefactorId       string   `json:"stackRefactorId"`
	Status                string   `json:"status"`
	StatusReason          string   `json:"statusReason,omitempty"`
	ExecutionStatus       string   `json:"executionStatus"`
	ExecutionStatusReason string   `json:"executionStatusReason,omitempty"`
	Description           string   `json:"description,omitempty"`
	StackIds              []string `json:"stackIds,omitempty"`
}

var refactorDescribeCmd = &cobra.Command{
	Use:   "describe",
	Short: "Describe the status of a stack refactor",
	RunE: func(cmd *cobra.Command, args []string) error {
		described, err := aws_lib.DescribeStackRefactor(cmd.Context(), profile, region, refactorId)
		if err != nil {
			return err
		}
		return writeJson(refactorDescribeResponse{
			StackRefactorId:       awssdk.ToString(described.StackRefactorId),
			Status:                string(described.Status),
			StatusReason:          awssdk.ToString(described.StatusReason),
			ExecutionStatus:       string(described.ExecutionStatus),
			ExecutionStatusReason: awssdk.ToString(described.ExecutionStatusReason),
			Description:           awssdk.ToString(described.Description),
			StackIds:              described.StackIds,
		})
	},
}

var refactorExecuteCmd = &cobra.Command{
	Use:   "execute",
	Short: "Execute a stack refactor",
	RunE: func(cmd *cobra.Command, args []string) error {
		if err := aws_lib.ExecuteStackRefactor(cmd.Context(), profile, region, refactorId); err != nil {
			return err
		}
		return writeJson(refactorIdResponse{StackRefactorId: refactorId})
	},
}

func init() {
	refactorCreateCmd.Flags().StringVar(&refactorCreatePayload, "payload", "", "JSON encoded refactor request")
	_ = refactorCreateCmd.MarkFlagRequired("payload")

	for _, command := range []*cobra.Command{refactorDescribeCmd, refactorExecuteCmd} {
		command.Flags().StringVar(&refactorId, "id", "", "stack refactor id")
		_ = command.MarkFlagRequired("id")
	}

	refactorCmd.AddCommand(refactorCreateCmd)
	refactorCmd.AddCommand(refactorDescribeCmd)
	refactorCmd.AddCommand(refactorExecuteCmd)

	rootCmd.AddCommand(refactorCmd)
}
