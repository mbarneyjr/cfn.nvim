package aws

import (
	"context"
	"errors"
	"fmt"

	awssdk "github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
)

func LoadConfig(ctx context.Context, profile string, region string) (awssdk.Config, error) {
	opts := []func(*config.LoadOptions) error{}
	if profile != "" {
		opts = append(opts, config.WithSharedConfigProfile(profile))
	}
	if region != "" {
		opts = append(opts, config.WithRegion(region))
	}
	cfg, err := config.LoadDefaultConfig(ctx, opts...)
	if err != nil {
		var notFound config.SharedConfigProfileNotExistError
		if errors.As(err, &notFound) {
			return awssdk.Config{}, fmt.Errorf("profile not found: %s", notFound.Profile)
		}
		return awssdk.Config{}, err
	}
	return cfg, nil
}
