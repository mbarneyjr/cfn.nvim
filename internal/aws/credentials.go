package aws

import (
	"context"
	"time"

	awssdk "github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/sts"
)

type Resolved struct {
	AccessKeyId     string
	SecretAccessKey string
	SessionToken    string
	Region          string
	AccountId       string
	Expiry          string
	ExpiryEpoch     int64
}

func Resolve(ctx context.Context, profile string, region string) (Resolved, error) {
	cfg, err := LoadConfig(ctx, profile, region)
	if err != nil {
		return Resolved{}, err
	}
	creds, err := cfg.Credentials.Retrieve(ctx)
	if err != nil {
		return Resolved{}, err
	}
	identity, err := sts.NewFromConfig(cfg).GetCallerIdentity(ctx, &sts.GetCallerIdentityInput{})
	if err != nil {
		return Resolved{}, err
	}
	resolved := Resolved{
		AccessKeyId:     creds.AccessKeyID,
		SecretAccessKey: creds.SecretAccessKey,
		SessionToken:    creds.SessionToken,
		Region:          cfg.Region,
		AccountId:       awssdk.ToString(identity.Account),
	}
	if creds.CanExpire {
		resolved.Expiry = creds.Expires.UTC().Format(time.RFC3339)
		resolved.ExpiryEpoch = creds.Expires.Unix()
	}
	return resolved, nil
}
