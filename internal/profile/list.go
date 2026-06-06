package profile

import (
	"os"
	"path/filepath"
	"sort"
	"strings"

	"gopkg.in/ini.v1"
)

func getCredentialsFile() (string, error) {
	if f := os.Getenv("AWS_SHARED_CREDENTIALS_FILE"); f != "" {
		return f, nil
	}
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(homeDir, ".aws", "credentials"), nil
}

func getConfigFile() (string, error) {
	if f := os.Getenv("AWS_CONFIG_FILE"); f != "" {
		return f, nil
	}
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(homeDir, ".aws", "config"), nil
}

func loadProfilesFromFile(filePath string, prefix string, seen map[string]bool) error {
	cfg, err := ini.Load(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	for _, section := range cfg.Sections() {
		name := strings.TrimPrefix(section.Name(), prefix)
		if name == "DEFAULT" {
			continue
		}
		if strings.HasPrefix(name, "sso-session ") {
			continue
		}
		seen[name] = true
	}
	return nil
}

func ListProfiles() ([]string, error) {
	seen := make(map[string]bool)
	credentialsFile, err := getCredentialsFile()
	if err == nil {
		if err := loadProfilesFromFile(credentialsFile, "", seen); err != nil {
			return nil, err
		}
	}
	configFile, err := getConfigFile()
	if err == nil {
		if err := loadProfilesFromFile(configFile, "profile ", seen); err != nil {
			return nil, err
		}
	}
	profiles := make([]string, 0, len(seen))
	for name := range seen {
		profiles = append(profiles, name)
	}
	sort.Strings(profiles)
	return profiles, nil
}
