package aws

import (
	"context"
	"fmt"
	"os"

	awssdk "github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/cloudformation"
	"github.com/aws/aws-sdk-go-v2/service/cloudformation/types"
)

type ResourceLocation struct {
	StackName string `json:"stack_name"`
	LogicalId string `json:"logical_id"`
}

type ResourceMapping struct {
	Source      ResourceLocation `json:"source"`
	Destination ResourceLocation `json:"destination"`
}

type StackDefinition struct {
	StackName    string `json:"stack_name"`
	TemplatePath string `json:"template_path"`
}

type RefactorRequest struct {
	StackDefinitions []StackDefinition `json:"stack_definitions"`
	Mappings         []ResourceMapping `json:"mappings"`
}

func cfnClient(ctx context.Context, profile string, region string) (*cloudformation.Client, error) {
	cfg, err := LoadConfig(ctx, profile, region)
	if err != nil {
		return nil, err
	}
	return cloudformation.NewFromConfig(cfg), nil
}

func location(l ResourceLocation) *types.ResourceLocation {
	return &types.ResourceLocation{
		StackName:         awssdk.String(l.StackName),
		LogicalResourceId: awssdk.String(l.LogicalId),
	}
}

func CreateStackRefactor(ctx context.Context, profile string, region string, request RefactorRequest) (string, error) {
	client, err := cfnClient(ctx, profile, region)
	if err != nil {
		return "", err
	}
	input := cloudformation.CreateStackRefactorInput{
		EnableStackCreation: awssdk.Bool(true),
	}
	for _, definition := range request.StackDefinitions {
		template, err := os.ReadFile(definition.TemplatePath)
		if err != nil {
			return "", fmt.Errorf("failed to read template for stack %s: %w", definition.StackName, err)
		}
		input.StackDefinitions = append(input.StackDefinitions, types.StackDefinition{
			StackName:    awssdk.String(definition.StackName),
			TemplateBody: awssdk.String(string(template)),
		})
	}
	for _, mapping := range request.Mappings {
		input.ResourceMappings = append(input.ResourceMappings, types.ResourceMapping{
			Source:      location(mapping.Source),
			Destination: location(mapping.Destination),
		})
	}
	output, err := client.CreateStackRefactor(ctx, &input)
	if err != nil {
		return "", err
	}
	return awssdk.ToString(output.StackRefactorId), nil
}

func DescribeStackRefactor(ctx context.Context, profile string, region string, id string) (*cloudformation.DescribeStackRefactorOutput, error) {
	client, err := cfnClient(ctx, profile, region)
	if err != nil {
		return nil, err
	}
	return client.DescribeStackRefactor(ctx, &cloudformation.DescribeStackRefactorInput{
		StackRefactorId: awssdk.String(id),
	})
}

func ExecuteStackRefactor(ctx context.Context, profile string, region string, id string) error {
	client, err := cfnClient(ctx, profile, region)
	if err != nil {
		return err
	}
	_, err = client.ExecuteStackRefactor(ctx, &cloudformation.ExecuteStackRefactorInput{
		StackRefactorId: awssdk.String(id),
	})
	return err
}
