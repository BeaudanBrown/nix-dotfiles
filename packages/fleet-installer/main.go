package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const (
	minimumUSBSize = int64(32 * 1024 * 1024 * 1024)
	payloadDir     = "/var/lib/fleet-installer"
	headscaleURL   = "https://hs.bepis.lol"
)

type runner interface {
	Run(stdin io.Reader, name string, args ...string) ([]byte, error)
	Interactive(name string, args ...string) error
}

type commandRunner struct {
	Dir     string
	Env     []string
	Out     io.Writer
	Timeout time.Duration
}

func (r commandRunner) commandContext(ctx context.Context, name string, args ...string) *exec.Cmd {
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Dir = r.Dir
	cmd.Env = append(os.Environ(), r.Env...)
	return cmd
}

func (r commandRunner) Run(stdin io.Reader, name string, args ...string) ([]byte, error) {
	timeout := r.Timeout
	if timeout == 0 {
		timeout = 2 * time.Minute
	}
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	cmd := r.commandContext(ctx, name, args...)
	cmd.Stdin = stdin
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			return stdout.Bytes(), fmt.Errorf("%s %s exceeded %s", name, strings.Join(args, " "), timeout)
		}
		return stdout.Bytes(), fmt.Errorf("%s %s: %w\n%s", name, strings.Join(args, " "), err, stderr.String())
	}
	return stdout.Bytes(), nil
}

func (r commandRunner) Interactive(name string, args ...string) error {
	cmd := r.commandContext(context.Background(), name, args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = r.Out
	cmd.Stderr = r.Out
	return cmd.Run()
}

type lsblkOutput struct {
	BlockDevices []blockDevice `json:"blockdevices"`
}

type blockDevice struct {
	Path        string        `json:"path"`
	Name        string        `json:"name"`
	Size        json.Number   `json:"size"`
	Model       string        `json:"model"`
	Serial      string        `json:"serial"`
	Transport   string        `json:"tran"`
	Removable   boolish       `json:"rm"`
	Type        string        `json:"type"`
	Mountpoints []interface{} `json:"mountpoints"`
	Children    []blockDevice `json:"children"`
}

type boolish bool

func (b *boolish) UnmarshalJSON(data []byte) error {
	value := strings.Trim(string(data), `"`)
	*b = boolish(value == "1" || strings.EqualFold(value, "true"))
	return nil
}

func removableDisks(data []byte) ([]blockDevice, error) {
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.UseNumber()
	var listing lsblkOutput
	if err := decoder.Decode(&listing); err != nil {
		return nil, fmt.Errorf("parse lsblk output: %w", err)
	}
	var devices []blockDevice
	for _, device := range listing.BlockDevices {
		size, err := device.Size.Int64()
		if err != nil {
			continue
		}
		if device.Type == "disk" && bool(device.Removable) && device.Transport == "usb" && size >= minimumUSBSize {
			devices = append(devices, device)
		}
	}
	return devices, nil
}

type prompt struct {
	in  *bufio.Reader
	out io.Writer
}

func (p prompt) line(message string) (string, error) {
	fmt.Fprint(p.out, message)
	value, err := p.in.ReadString('\n')
	return strings.TrimSpace(value), err
}

func (p prompt) confirm(message string, defaultYes bool) (bool, error) {
	suffix := " [y/N]: "
	if defaultYes {
		suffix = " [Y/n]: "
	}
	answer, err := p.line(message + suffix)
	if err != nil {
		return false, err
	}
	if answer == "" {
		return defaultYes, nil
	}
	return strings.EqualFold(answer, "y") || strings.EqualFold(answer, "yes"), nil
}

func (p prompt) choose(message string, choices []string) (int, error) {
	if len(choices) == 0 {
		return -1, errors.New("no choices available")
	}
	fmt.Fprintln(p.out, message)
	for index, choice := range choices {
		fmt.Fprintf(p.out, "  %d. %s\n", index+1, choice)
	}
	for {
		value, err := p.line("Select: ")
		if err != nil {
			return -1, err
		}
		selected, err := strconv.Atoi(value)
		if err == nil && selected > 0 && selected <= len(choices) {
			return selected - 1, nil
		}
		fmt.Fprintln(p.out, "Invalid selection.")
	}
}

type wifiProfile struct {
	ID      string
	SSID    string
	KeyMgmt string
	PSK     string
}

func renderWiFiProfile(profile wifiProfile) string {
	keyMgmt := profile.KeyMgmt
	if keyMgmt == "" {
		keyMgmt = "wpa-psk"
	}
	return fmt.Sprintf(`[connection]
id=%s
type=wifi
autoconnect=true

[wifi]
mode=infrastructure
ssid=%s

[wifi-security]
key-mgmt=%s
psk=%s

[ipv4]
method=auto

[ipv6]
method=auto
`, profile.ID, profile.SSID, keyMgmt, profile.PSK)
}

type rekeyRequest struct {
	TargetHost string `json:"targetHost"`
	SopsYAML   string `json:"sopsYamlBase64"`
}

type rekeyResponse struct {
	Commit string `json:"commit"`
}

func main() {
	log.SetFlags(0)
	if len(os.Args) < 2 {
		usage()
	}
	var err error
	switch os.Args[1] {
	case "provision-usb":
		err = provisionUSB(commandRunner{Out: os.Stdout, Timeout: 5 * time.Minute}, prompt{bufio.NewReader(os.Stdin), os.Stdout})
	case "install-host":
		err = installHost(commandRunner{Out: os.Stdout}, prompt{bufio.NewReader(os.Stdin), os.Stdout})
	case "nas-rekey":
		err = nasRekey(commandRunner{Out: os.Stdout}, os.Stdin, os.Stdout)
	case "version":
		fmt.Println("fleet-installer 0.1.0")
	default:
		usage()
	}
	if err != nil {
		log.Fatal("fleet-installer: ", err)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: fleet-installer <provision-usb|install-host|nas-rekey|version>")
	os.Exit(2)
}

func requireCleanDefaultBranch(r runner, repo string) error {
	status, err := r.Run(nil, "git", "-C", repo, "status", "--porcelain")
	if err != nil {
		return err
	}
	if len(bytes.TrimSpace(status)) != 0 {
		return errors.New("dotfiles checkout must be clean")
	}
	branch, err := r.Run(nil, "git", "-C", repo, "branch", "--show-current")
	if err != nil {
		return err
	}
	remoteDefault, err := r.Run(nil, "git", "-C", repo, "symbolic-ref", "--short", "refs/remotes/origin/HEAD")
	if err != nil {
		return errors.New("origin/HEAD is not configured")
	}
	if strings.TrimSpace(string(branch)) != strings.TrimPrefix(strings.TrimSpace(string(remoteDefault)), "origin/") {
		return errors.New("physical USB provisioning requires the remote default branch")
	}
	if _, err := r.Run(nil, "git", "-C", repo, "fetch", "--quiet", "origin"); err != nil {
		return err
	}
	local, err := r.Run(nil, "git", "-C", repo, "rev-parse", "HEAD")
	if err != nil {
		return err
	}
	remote, err := r.Run(nil, "git", "-C", repo, "rev-parse", "@{upstream}")
	if err != nil {
		return err
	}
	if !bytes.Equal(bytes.TrimSpace(local), bytes.TrimSpace(remote)) {
		return errors.New("dotfiles default branch must be pushed and up to date")
	}
	return nil
}

func repositoryRoot(r runner) (string, error) {
	output, err := r.Run(nil, "git", "rev-parse", "--show-toplevel")
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

type provisionInputs struct {
	HeadscaleKey string
	SSHKey       string
	WiFiProfiles []wifiProfile
}

func provisionUSB(r runner, p prompt) error {
	if os.Geteuid() == 0 && os.Getenv("FLEET_INSTALLER_TEST_ALLOW_ROOT") != "1" {
		return errors.New("run provision-usb as your normal user; it invokes sudo only when needed")
	}
	repo, err := repositoryRoot(r)
	if err != nil {
		return err
	}
	if os.Getenv("FLEET_INSTALLER_TEST_ALLOW_DIRTY") != "1" {
		if err := requireCleanDefaultBranch(r, repo); err != nil {
			return err
		}
	}
	inputs, err := collectProvisionInputs(r, p)
	if err != nil {
		return err
	}
	if _, err := r.Run(nil, "nix", "eval", "--raw", repo+"#nixosConfigurations.installer.config.system.build.toplevel.drvPath"); err != nil {
		return fmt.Errorf("installer configuration does not evaluate: %w", err)
	}
	listing, err := r.Run(nil, "lsblk", "--json", "--bytes", "--output", "PATH,NAME,SIZE,MODEL,SERIAL,TRAN,RM,TYPE,MOUNTPOINTS")
	if err != nil {
		return err
	}
	devices, err := removableDisks(listing)
	if err != nil {
		return err
	}
	labels := make([]string, len(devices))
	for index, device := range devices {
		size, _ := device.Size.Int64()
		labels[index] = fmt.Sprintf("%s — %s — %s — %.1f GiB", device.Path, strings.TrimSpace(device.Model), strings.TrimSpace(device.Serial), float64(size)/(1024*1024*1024))
	}
	selected := 0
	confirmed := false
	if os.Getenv("FLEET_INSTALLER_TEST_CONFIRM") == "1" {
		if len(devices) == 0 {
			return errors.New("no removable USB device available")
		}
		confirmed = true
	} else {
		selected, err = p.choose("Removable USB devices (minimum 32 GiB):", labels)
		if err != nil {
			return err
		}
		confirmed, err = p.confirm("Erase "+labels[selected]+"?", false)
		if err != nil {
			return err
		}
	}
	if !confirmed {
		return errors.New("provisioning cancelled")
	}
	device := devices[selected]

	password, err := askPassword(r, "USB LUKS passphrase")
	if err != nil {
		return err
	}
	confirmation, err := askPassword(r, "Repeat USB LUKS passphrase")
	if err != nil {
		return err
	}
	if password != confirmation || password == "" {
		return errors.New("USB LUKS passphrases do not match")
	}

	staging, err := os.MkdirTemp("", "fleet-installer-provision-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(staging)
	passwordFile := filepath.Join(staging, "luks-password")
	if err := os.WriteFile(passwordFile, []byte(password), 0o600); err != nil {
		return err
	}
	layoutPath := filepath.Join(staging, "usb-layout.nix")
	if err := os.WriteFile(layoutPath, []byte(usbLayout(device.Path, passwordFile)), 0o600); err != nil {
		return err
	}

	clonePath := filepath.Join(staging, "nix-dotfiles")
	remote, err := r.Run(nil, "git", "-C", repo, "remote", "get-url", "origin")
	if err != nil {
		return err
	}
	if os.Getenv("FLEET_INSTALLER_TEST_COPY_REPO") == "1" {
		if err := r.Interactive("cp", "-a", repo, clonePath); err != nil {
			return err
		}
	} else if _, err := r.Run(nil, "git", "clone", "--quiet", strings.TrimSpace(string(remote)), clonePath); err != nil {
		return err
	}

	fmt.Fprintln(p.out, "Provisioning encrypted installer USB. This can take several minutes.")
	if os.Getenv("FLEET_INSTALLER_TEST_USE_PATH_DISKO") == "1" {
		if err := r.Interactive("sudo", "disko", "--mode", "disko", layoutPath); err != nil {
			return err
		}
	} else if err := r.Interactive("sudo", "nix", "run", repo+"#disko", "--", "--mode", "disko", layoutPath); err != nil {
		return err
	}
	if err := r.Interactive("sudo", "nixos-install", "--root", "/mnt", "--flake", repo+"#installer", "--no-root-password", "--no-channel-copy", "--option", "accept-flake-config", "true"); err != nil {
		return err
	}

	if err := provisionPayload(r, repo, clonePath, staging, inputs); err != nil {
		return err
	}
	if err := r.Interactive("sudo", "umount", "-R", "/mnt"); err != nil {
		return err
	}
	fmt.Fprintln(p.out, "Encrypted fleet installer USB created successfully.")
	return nil
}

func askPassword(r runner, message string) (string, error) {
	if password := os.Getenv("FLEET_INSTALLER_TEST_LUKS_PASSWORD"); password != "" {
		return password, nil
	}
	output, err := r.Run(nil, "systemd-ask-password", "--timeout=0", message)
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

func usbLayout(device, passwordFile string) string {
	return fmt.Sprintf(`{
  disko.devices.disk.installer = {
    type = "disk";
    device = %q;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          start = "1M";
          end = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
            extraArgs = [ "-n" "INST_BOOT" ];
          };
        };
        root = {
          size = "100%%";
          content = {
            type = "luks";
            name = "installer-root";
            passwordFile = %q;
            extraFormatArgs = [ "--label" "INSTALLER_LUKS" ];
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              extraArgs = [ "-L" "INSTALLER_ROOT" ];
            };
          };
        };
      };
    };
  };
}
`, device, passwordFile)
}

func collectProvisionInputs(r runner, p prompt) (provisionInputs, error) {
	inputs := provisionInputs{}
	inputs.HeadscaleKey = os.Getenv("FLEET_INSTALLER_HEADSCALE_KEY_FILE")
	if inputs.HeadscaleKey == "" {
		inputs.HeadscaleKey = "/run/secrets/headscale/installer_pre_auth"
	}
	if info, err := os.Stat(inputs.HeadscaleKey); err != nil || info.Size() == 0 {
		return inputs, fmt.Errorf("required SOPS secret %s is unavailable", inputs.HeadscaleKey)
	}

	if configured := os.Getenv("FLEET_INSTALLER_SSH_KEY_FILE"); configured != "" {
		inputs.SSHKey = configured
	} else {
		home, _ := os.UserHomeDir()
		candidates, _ := filepath.Glob(filepath.Join(home, ".ssh", "id_*"))
		var privateKeys []string
		for _, candidate := range candidates {
			if strings.HasSuffix(candidate, ".pub") || strings.Contains(filepath.Base(candidate), "-cert.") {
				continue
			}
			if info, err := os.Stat(candidate); err == nil && info.Mode().IsRegular() {
				if _, err := os.Stat(candidate + ".pub"); err == nil {
					privateKeys = append(privateKeys, candidate)
				}
			}
		}
		sort.Strings(privateKeys)
		if len(privateKeys) == 0 {
			return inputs, errors.New("no SSH private/public identity pair found under ~/.ssh")
		}
		selected := 0
		if len(privateKeys) > 1 {
			var err error
			selected, err = p.choose("Select the Git and NAS SSH identity:", privateKeys)
			if err != nil {
				return inputs, err
			}
		}
		inputs.SSHKey = privateKeys[selected]
	}
	if info, err := os.Stat(inputs.SSHKey); err != nil || info.Size() == 0 {
		return inputs, fmt.Errorf("Git SSH identity %s is unavailable", inputs.SSHKey)
	}
	if _, err := os.Stat(inputs.SSHKey + ".pub"); err != nil {
		return inputs, fmt.Errorf("Git SSH public key %s.pub is unavailable", inputs.SSHKey)
	}
	profiles, err := collectWiFiProfiles(r)
	if err != nil {
		return inputs, err
	}
	inputs.WiFiProfiles = profiles
	return inputs, nil
}

func provisionPayload(r runner, repo, clonePath, staging string, inputs provisionInputs) error {
	target := "/mnt" + payloadDir
	if err := r.Interactive("sudo", "install", "-d", "-m", "0700", target, target+"/wifi", target+"/.ssh"); err != nil {
		return err
	}
	if err := r.Interactive("sudo", "cp", "-a", clonePath, target+"/nix-dotfiles"); err != nil {
		return err
	}

	if err := r.Interactive("sudo", "install", "-m", "0600", inputs.HeadscaleKey, target+"/headscale-auth-key"); err != nil {
		return err
	}

	home, _ := os.UserHomeDir()
	privateKey := inputs.SSHKey
	publicKey := privateKey + ".pub"
	if err := r.Interactive("sudo", "install", "-m", "0600", privateKey, target+"/.ssh/id_ed25519"); err != nil {
		return err
	}
	if err := r.Interactive("sudo", "install", "-m", "0644", publicKey, target+"/.ssh/id_ed25519.pub"); err != nil {
		return err
	}
	if err := r.Interactive("sudo", "install", "-d", "-m", "0700", "/mnt/home/installer/.ssh"); err != nil {
		return err
	}
	if err := r.Interactive("sudo", "install", "-m", "0600", publicKey, "/mnt/home/installer/.ssh/authorized_keys"); err != nil {
		return err
	}
	if err := r.Interactive("sudo", "chown", "-R", "1000:100", "/mnt/home/installer"); err != nil {
		return err
	}
	for _, name := range []string{"config", "known_hosts"} {
		source := filepath.Join(home, ".ssh", name)
		if _, err := os.Stat(source); err == nil {
			if err := r.Interactive("sudo", "install", "-m", "0600", source, target+"/.ssh/"+name); err != nil {
				return err
			}
		}
	}

	for index, profile := range inputs.WiFiProfiles {
		path := filepath.Join(staging, fmt.Sprintf("wifi-%d.nmconnection", index))
		if err := os.WriteFile(path, []byte(renderWiFiProfile(profile)), 0o600); err != nil {
			return err
		}
		if err := r.Interactive("sudo", "install", "-m", "0600", path, target+"/wifi/"+filepath.Base(path)); err != nil {
			return err
		}
	}
	if err := r.Interactive("sudo", "install", "-m", "0644", filepath.Join(repo, "flake.lock"), target+"/provisioned-flake.lock"); err != nil {
		return err
	}
	return r.Interactive("sudo", "chown", "-R", "1000:100", target)
}

func collectWiFiProfiles(r runner) ([]wifiProfile, error) {
	if psk := os.Getenv("FLEET_INSTALLER_TEST_WIFI_PSK"); psk != "" {
		return []wifiProfile{{ID: "installer-test", SSID: "installer-test", KeyMgmt: "wpa-psk", PSK: psk}}, nil
	}
	active, err := r.Run(nil, "nmcli", "--terse", "--fields", "NAME,TYPE", "connection", "show", "--active")
	if err != nil {
		return nil, err
	}
	var profiles []wifiProfile
	for _, line := range strings.Split(strings.TrimSpace(string(active)), "\n") {
		parts := strings.SplitN(line, ":", 2)
		if len(parts) != 2 || parts[1] != "802-11-wireless" {
			continue
		}
		values, err := r.Run(nil, "nmcli", "--show-secrets", "--get-values", "802-11-wireless.ssid,802-11-wireless-security.key-mgmt,802-11-wireless-security.psk", "connection", "show", parts[0])
		if err != nil {
			return nil, err
		}
		fields := strings.Split(strings.TrimSpace(string(values)), "\n")
		if len(fields) >= 3 && fields[0] != "" && fields[2] != "" {
			profiles = append(profiles, wifiProfile{ID: "installer-" + fields[0], SSID: fields[0], KeyMgmt: fields[1], PSK: fields[2]})
		}
	}
	if len(profiles) == 0 {
		return nil, errors.New("no active WPA Personal NetworkManager profile with a readable PSK; connect first or use nmtui")
	}
	return profiles, nil
}

// The destructive installation workflow is intentionally kept linear. A failed
// run leaves its redacted log on the encrypted USB and the next invocation starts
// over, as selected by the repository owner.
func installHost(r runner, p prompt) error {
	if os.Geteuid() != 0 {
		return r.Interactive("sudo", "-n", os.Args[0], "install-host")
	}
	repo := filepath.Join(payloadDir, "nix-dotfiles")
	logDir := filepath.Join(payloadDir, "logs")
	if err := os.MkdirAll(logDir, 0o700); err != nil {
		return err
	}
	logPath := filepath.Join(logDir, time.Now().UTC().Format("20060102T150405Z")+".log")
	logFile, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_EXCL, 0o600)
	if err != nil {
		return err
	}
	defer logFile.Close()
	live := commandRunner{
		Dir: repo,
		Env: []string{
			"HOME=" + payloadDir,
			"GIT_SSH_COMMAND=ssh -F " + payloadDir + "/.ssh/config -i " + payloadDir + "/.ssh/id_ed25519",
			"GIT_AUTHOR_NAME=Fleet Installer",
			"GIT_AUTHOR_EMAIL=beaudan.brown@gmail.com",
			"GIT_COMMITTER_NAME=Fleet Installer",
			"GIT_COMMITTER_EMAIL=beaudan.brown@gmail.com",
		},
		Out:     io.MultiWriter(os.Stdout, logFile),
		Timeout: 5 * time.Minute,
	}

	if _, err := live.Run(nil, "git", "fetch", "--quiet", "origin"); err != nil {
		return err
	}
	if _, err := live.Run(nil, "git", "merge", "--ff-only", "@{upstream}"); err != nil {
		return err
	}

	hosts, err := discoverHosts(live, repo)
	if err != nil {
		return err
	}
	if len(hosts) == 0 {
		return errors.New("no eligible x86_64 Disko hosts found")
	}
	labels := make([]string, len(hosts))
	for index, host := range hosts {
		marker := ""
		if host.AllDisksPresent {
			marker = " [detected]"
		}
		labels[index] = host.Name + marker + " — " + strings.Join(host.Disks, ", ")
	}
	selected := -1
	if testHost := os.Getenv("FLEET_INSTALLER_TEST_HOST"); testHost != "" {
		for index, candidate := range hosts {
			if candidate.Name == testHost {
				selected = index
				break
			}
		}
		if selected < 0 {
			return fmt.Errorf("test host %q is not eligible", testHost)
		}
	} else {
		selected, err = p.choose("Select installation host:", labels)
		if err != nil {
			return err
		}
	}
	host := hosts[selected]
	if !host.AllDisksPresent {
		return errors.New("selected host's declared Disko devices are not all present")
	}
	installerDevice, err := currentRootDisk(live)
	if err != nil {
		return fmt.Errorf("identify installer USB: %w", err)
	}
	for _, targetDevice := range host.Disks {
		resolved, err := filepath.EvalSymlinks(targetDevice)
		if err != nil {
			return fmt.Errorf("resolve target disk %s: %w", targetDevice, err)
		}
		if resolved == installerDevice {
			return fmt.Errorf("refusing to erase installer USB %s", installerDevice)
		}
	}

	regenerate := false
	if os.Getenv("FLEET_INSTALLER_TEST_CONFIRM") != "1" {
		regenerate, err = p.confirm("Regenerate and overwrite hosts/"+host.Name+"/hardware.nix?", false)
		if err != nil {
			return err
		}
	}
	targetPassword := ""
	if host.UsesLUKS {
		targetPassword, err = askPassword(live, "Target LUKS passphrase")
		if err != nil {
			return err
		}
		confirmation, err := askPassword(live, "Repeat target LUKS passphrase")
		if err != nil || targetPassword == "" || targetPassword != confirmation {
			return errors.New("target LUKS passphrases do not match")
		}
	}
	plan := fmt.Sprintf("Install %q, rotate host/user Age identities, push both repositories, and ERASE:\n  %s", host.Name, strings.Join(host.Disks, "\n  "))
	confirmed := os.Getenv("FLEET_INSTALLER_TEST_CONFIRM") == "1"
	if !confirmed {
		confirmed, err = p.confirm(plan+"\nContinue?", false)
		if err != nil {
			return err
		}
	}
	if !confirmed {
		return errors.New("installation cancelled")
	}

	if regenerate {
		if err := regenerateHardware(live, repo, host.Name); err != nil {
			return err
		}
	}
	identities, err := generateIdentities(live, host)
	if err != nil {
		return err
	}
	if err := updateHostSpec(repo, host.Name, identities); err != nil {
		return err
	}
	if err := rekeyAndPush(live, repo, host.Name); err != nil {
		return err
	}

	passwordFile := "/tmp/disko-password"
	if host.UsesLUKS {
		if err := os.WriteFile(passwordFile, []byte(targetPassword), 0o600); err != nil {
			return err
		}
		defer os.Remove(passwordFile)
	}

	if err := live.Interactive("nix", "run", repo+"#disko", "--", "--mode", "disko", "--flake", repo+"#"+host.Name); err != nil {
		return err
	}
	if err := seedTarget(live, repo, host, identities, logPath); err != nil {
		return err
	}
	if err := live.Interactive("nixos-install", "--root", "/mnt", "--flake", repo+"#"+host.Name, "--no-root-password", "--no-channel-copy", "--show-trace", "--option", "accept-flake-config", "true"); err != nil {
		return err
	}
	if err := finalizeTarget(live, host, logPath); err != nil {
		return err
	}

	_ = live.Interactive("tailscale", "logout")
	if os.Getenv("FLEET_INSTALLER_TEST_NO_REBOOT") == "1" {
		fmt.Fprintln(live.Out, "Installation complete; test mode suppressed reboot.")
		return nil
	}
	fmt.Fprintln(live.Out, "Installation complete. Rebooting in 10 seconds; press Ctrl-C to cancel.")
	time.Sleep(10 * time.Second)
	return live.Interactive("systemctl", "reboot")
}

func currentRootDisk(r runner) (string, error) {
	sourceOutput, err := r.Run(nil, "findmnt", "--noheadings", "--output", "SOURCE", "/")
	if err != nil {
		return "", err
	}
	source := strings.TrimSpace(string(sourceOutput))
	ancestry, err := r.Run(nil, "lsblk", "--inverse", "--noheadings", "--paths", "--output", "PATH,TYPE", source)
	if err != nil {
		return "", err
	}
	for _, line := range strings.Split(string(ancestry), "\n") {
		fields := strings.Fields(line)
		if len(fields) == 2 && fields[1] == "disk" {
			return filepath.EvalSymlinks(fields[0])
		}
	}
	return "", fmt.Errorf("no disk ancestor found for root source %s", source)
}

type hostMetadata struct {
	Name            string
	Disks           []string
	Users           []userMetadata
	UsesLUKS        bool
	AllDisksPresent bool
}

type userMetadata struct {
	Username string `json:"username"`
	Home     string `json:"home"`
	UID      int    `json:"uid"`
}

type evaluatedDisk struct {
	Device string `json:"device"`
}

type hostSpecDocument struct {
	HostSpecs map[string]struct {
		Users []struct {
			Username string `json:"username"`
			UID      int    `json:"uid"`
		} `json:"users"`
	} `json:"hostSpecs"`
}

func discoverHosts(r runner, repo string) ([]hostMetadata, error) {
	specContent, err := os.ReadFile(filepath.Join(repo, "modules", "host-spec", "all-hosts.json"))
	if err != nil {
		return nil, err
	}
	var specs hostSpecDocument
	if err := json.Unmarshal(specContent, &specs); err != nil {
		return nil, fmt.Errorf("parse host specs: %w", err)
	}

	diskoDir := filepath.Join(repo, "modules", "system", "disko")
	entries, err := os.ReadDir(diskoDir)
	if err != nil {
		return nil, err
	}
	excluded := map[string]bool{
		"nas": true, "iso": true, "installer": true, "oneplus": true, "pi4": true,
		"btrfs": true, "btrfs_2_drives": true, "btrfs_luks": true,
	}
	var hosts []hostMetadata
	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".nix" {
			continue
		}
		name := strings.TrimSuffix(entry.Name(), ".nix")
		spec, known := specs.HostSpecs[name]
		if excluded[name] || !known {
			continue
		}
		modulePath := filepath.Join(diskoDir, entry.Name())
		expression := fmt.Sprintf(
			`let cfg = import %s {}; in builtins.mapAttrs (_: disk: { device = disk.device; }) cfg.disko.devices.disk`,
			modulePath,
		)
		output, err := r.Run(nil, "nix", "eval", "--json", "--impure", "--expr", expression)
		if err != nil {
			return nil, fmt.Errorf("evaluate Disko metadata for %s: %w", name, err)
		}
		var disks map[string]evaluatedDisk
		if err := json.Unmarshal(output, &disks); err != nil {
			return nil, fmt.Errorf("parse Disko metadata for %s: %w", name, err)
		}
		host := hostMetadata{Name: name, AllDisksPresent: len(disks) > 0}
		for _, user := range spec.Users {
			host.Users = append(host.Users, userMetadata{
				Username: user.Username,
				Home:     "/home/" + user.Username,
				UID:      user.UID,
			})
		}
		for _, disk := range disks {
			host.Disks = append(host.Disks, disk.Device)
			if _, err := os.Stat(disk.Device); err != nil {
				host.AllDisksPresent = false
			}
		}
		content, _ := os.ReadFile(modulePath)
		host.UsesLUKS = bytes.Contains(content, []byte("btrfs_luks.nix"))
		sort.Strings(host.Disks)
		hosts = append(hosts, host)
	}
	sort.Slice(hosts, func(i, j int) bool { return hosts[i].Name < hosts[j].Name })
	return hosts, nil
}

type generatedIdentities struct {
	HostPrivate string
	HostPublic  string
	HostAge     string
	Users       map[string]generatedUserIdentity
}

type generatedUserIdentity struct {
	Private string
	Public  string
}

func generateIdentities(r runner, host hostMetadata) (generatedIdentities, error) {
	directory, err := os.MkdirTemp(payloadDir, "identities-*")
	if err != nil {
		return generatedIdentities{}, err
	}
	identity := generatedIdentities{HostPrivate: filepath.Join(directory, "ssh_host_ed25519_key"), Users: map[string]generatedUserIdentity{}}
	identity.HostPublic = identity.HostPrivate + ".pub"
	if _, err := r.Run(nil, "ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-C", "root@"+host.Name, "-f", identity.HostPrivate); err != nil {
		return identity, err
	}
	public, err := os.ReadFile(identity.HostPublic)
	if err != nil {
		return identity, err
	}
	age, err := r.Run(bytes.NewReader(public), "ssh-to-age")
	if err != nil {
		return identity, err
	}
	identity.HostAge = strings.TrimSpace(string(age))
	for _, user := range host.Users {
		path := filepath.Join(directory, user.Username+"-age-key.txt")
		output, err := r.Run(nil, "age-keygen", "-o", path)
		if err != nil {
			return identity, err
		}
		publicKey := ""
		for _, line := range strings.Split(string(output), "\n") {
			if strings.HasPrefix(line, "Public key:") {
				publicKey = strings.TrimSpace(strings.TrimPrefix(line, "Public key:"))
			}
		}
		if publicKey == "" {
			content, _ := os.ReadFile(path)
			for _, line := range strings.Split(string(content), "\n") {
				if strings.HasPrefix(line, "# public key:") {
					publicKey = strings.TrimSpace(strings.TrimPrefix(line, "# public key:"))
				}
			}
		}
		identity.Users[user.Username] = generatedUserIdentity{Private: path, Public: publicKey}
	}
	return identity, nil
}

func updateHostSpec(repo, hostname string, identities generatedIdentities) error {
	path := filepath.Join(repo, "modules", "host-spec", "all-hosts.json")
	content, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	var document map[string]interface{}
	if err := json.Unmarshal(content, &document); err != nil {
		return err
	}
	hosts := document["hostSpecs"].(map[string]interface{})
	host := hosts[hostname].(map[string]interface{})
	host["ageHostKey"] = identities.HostAge
	users := host["users"].([]interface{})
	for index, raw := range users {
		user := raw.(map[string]interface{})
		name := user["username"].(string)
		user["uid"] = 1000 + index
		user["ageUserKey"] = identities.Users[name].Public
	}
	updated, err := json.MarshalIndent(document, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, append(updated, '\n'), 0o644)
}

func regenerateHardware(r runner, repo, host string) error {
	directory, err := os.MkdirTemp("", "fleet-hardware-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(directory)
	if _, err := r.Run(nil, "nixos-generate-config", "--no-filesystems", "--root", directory); err != nil {
		return err
	}
	return copyFile(filepath.Join(directory, "etc/nixos/hardware-configuration.nix"), filepath.Join(repo, "hosts", host, "hardware.nix"), 0o644)
}

func rekeyAndPush(r runner, repo, host string) error {
	yaml, err := r.Run(nil, filepath.Join(repo, "scripts", "gen-sops-yaml.sh"), "-")
	if err != nil {
		return err
	}
	request, _ := json.Marshal(rekeyRequest{TargetHost: host, SopsYAML: base64.StdEncoding.EncodeToString(yaml)})
	var response []byte
	localSOPS := os.Getenv("FLEET_INSTALLER_TEST_LOCAL_SOPS_REPO")
	if localSOPS != "" {
		previousRepo := os.Getenv("FLEET_INSTALLER_SOPS_REPO")
		os.Setenv("FLEET_INSTALLER_TEST", "1")
		os.Setenv("FLEET_INSTALLER_SOPS_REPO", localSOPS)
		var localResponse bytes.Buffer
		err = nasRekey(r, bytes.NewReader(request), &localResponse)
		if previousRepo == "" {
			os.Unsetenv("FLEET_INSTALLER_SOPS_REPO")
		} else {
			os.Setenv("FLEET_INSTALLER_SOPS_REPO", previousRepo)
		}
		if err != nil {
			return err
		}
		response = localResponse.Bytes()
		if _, err := r.Run(nil, "git", "-C", localSOPS, "pull", "--ff-only"); err != nil {
			return err
		}
	} else {
		response, err = r.Run(bytes.NewReader(request), "ssh", "nas", "installer-sops-rekey")
		if err != nil {
			return err
		}
	}
	var result rekeyResponse
	if err := json.Unmarshal(bytes.TrimSpace(response), &result); err != nil || result.Commit == "" {
		return fmt.Errorf("invalid NAS rekey response: %s", response)
	}
	if _, err := r.Run(nil, "nix", "flake", "update", "sopsSecrets"); err != nil {
		return err
	}
	addPaths := []string{
		"add",
		"modules/host-spec/all-hosts.json",
		"flake.lock",
		filepath.Join("hosts", host, "hardware.nix"),
	}
	if os.Getenv("FLEET_INSTALLER_TEST_LOCAL_SOPS_REPO") != "" {
		addPaths = append(addPaths, "test-sops-secrets")
	}
	if _, err := r.Run(nil, "git", addPaths...); err != nil {
		return err
	}
	message := "Rotate installer identities for " + host
	if _, err := r.Run(nil, "git", "commit", "-m", message); err != nil {
		return err
	}
	if os.Getenv("FLEET_INSTALLER_TEST_LOCAL_SOPS_REPO") != "" {
		return nil
	}
	_, err = r.Run(nil, "git", "push", "origin", "HEAD")
	return err
}

func seedTarget(r runner, repo string, host hostMetadata, identities generatedIdentities, logPath string) error {
	for _, directory := range []string{"/mnt/etc/ssh", "/mnt/etc/NetworkManager/system-connections", "/mnt/var/log/fleet-installer"} {
		if err := os.MkdirAll(directory, 0o700); err != nil {
			return err
		}
	}
	if err := copyFile(identities.HostPrivate, "/mnt/etc/ssh/ssh_host_ed25519_key", 0o600); err != nil {
		return err
	}
	if err := copyFile(identities.HostPublic, "/mnt/etc/ssh/ssh_host_ed25519_key.pub", 0o644); err != nil {
		return err
	}
	for _, user := range host.Users {
		key := identities.Users[user.Username]
		directory := "/mnt" + user.Home + "/.config/sops/age"
		if err := os.MkdirAll(directory, 0o700); err != nil {
			return err
		}
		path := filepath.Join(directory, "keys.txt")
		if err := copyFile(key.Private, path, 0o600); err != nil {
			return err
		}
		if err := os.Chown(directory, user.UID, 100); err != nil {
			return err
		}
		if err := os.Chown(path, user.UID, 100); err != nil {
			return err
		}
	}
	profiles, _ := filepath.Glob(filepath.Join(payloadDir, "wifi", "*.nmconnection"))
	for _, profile := range profiles {
		if err := copyFile(profile, filepath.Join("/mnt/etc/NetworkManager/system-connections", filepath.Base(profile)), 0o600); err != nil {
			return err
		}
	}
	destination := "/mnt" + host.Users[0].Home + "/documents/nix-dotfiles"
	if err := os.MkdirAll(filepath.Dir(destination), 0o755); err != nil {
		return err
	}
	if err := r.Interactive("cp", "-a", repo, destination); err != nil {
		return err
	}
	if err := r.Interactive("chown", "-R", fmt.Sprintf("%d:100", host.Users[0].UID), destination); err != nil {
		return err
	}
	return copyFile(logPath, "/mnt/var/log/fleet-installer/install.log", 0o600)
}

func finalizeTarget(r runner, host hostMetadata, logPath string) error {
	if err := copyFile(logPath, "/mnt/var/log/fleet-installer/install.log", 0o600); err != nil {
		return err
	}
	bootSource, err := r.Run(nil, "findmnt", "--noheadings", "--output", "SOURCE", "/mnt/boot")
	if err != nil {
		return err
	}
	partition := strings.TrimSpace(string(bootSource))
	parent, err := r.Run(nil, "lsblk", "--noheadings", "--output", "PKNAME", partition)
	if err != nil {
		return err
	}
	partNumber, err := r.Run(nil, "lsblk", "--noheadings", "--output", "PARTN", partition)
	if err != nil {
		return err
	}
	if err := r.Interactive("efibootmgr", "--create", "--disk", "/dev/"+strings.TrimSpace(string(parent)), "--part", strings.TrimSpace(string(partNumber)), "--label", "NixOS "+host.Name, "--loader", `\EFI\systemd\systemd-bootx64.efi`); err != nil {
		return err
	}
	entries, err := r.Run(nil, "efibootmgr")
	if err != nil {
		return err
	}
	entry := ""
	for _, line := range strings.Split(string(entries), "\n") {
		if strings.Contains(line, "NixOS "+host.Name) && strings.HasPrefix(line, "Boot") {
			entry = line[4:8]
		}
	}
	if entry == "" {
		return errors.New("could not identify target UEFI entry")
	}
	return r.Interactive("efibootmgr", "--bootnext", entry)
}

func nasRekey(r runner, input io.Reader, output io.Writer) error {
	if os.Getenv("USER") != "beau" && os.Getenv("FLEET_INSTALLER_TEST") != "1" {
		return errors.New("nas-rekey must run as beau")
	}
	var request rekeyRequest
	if err := json.NewDecoder(input).Decode(&request); err != nil {
		return fmt.Errorf("decode request: %w", err)
	}
	yaml, err := base64.StdEncoding.DecodeString(request.SopsYAML)
	if err != nil {
		return fmt.Errorf("decode sops configuration: %w", err)
	}
	repository := os.Getenv("FLEET_INSTALLER_SOPS_REPO")
	if repository == "" {
		repository = "/home/beau/sops-secrets"
	}
	lockPath := filepath.Join(repository, ".git", "fleet-installer.lock")
	lock, err := os.OpenFile(lockPath, os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return err
	}
	defer lock.Close()
	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX); err != nil {
		return fmt.Errorf("lock SOPS repository: %w", err)
	}
	defer syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)
	status, err := r.Run(nil, "git", "-C", repository, "status", "--porcelain")
	if err != nil {
		return err
	}
	if len(bytes.TrimSpace(status)) != 0 {
		return errors.New("SOPS repository must be clean")
	}
	if _, err := r.Run(nil, "git", "-C", repository, "pull", "--ff-only", "--quiet"); err != nil {
		return err
	}
	worktree, err := os.MkdirTemp("", "fleet-sops-rekey-*")
	if err != nil {
		return err
	}
	os.Remove(worktree)
	defer os.RemoveAll(worktree)
	if _, err := r.Run(nil, "git", "-C", repository, "worktree", "add", "--detach", worktree, "HEAD"); err != nil {
		return err
	}
	defer r.Run(nil, "git", "-C", repository, "worktree", "remove", "--force", worktree)
	if err := os.WriteFile(filepath.Join(worktree, ".sops.yaml"), yaml, 0o600); err != nil {
		return err
	}
	files, err := filepath.Glob(filepath.Join(worktree, "secrets", "*.yaml"))
	if err != nil || len(files) == 0 {
		return errors.New("no managed SOPS files found")
	}
	workRunner := commandRunner{Dir: worktree, Out: io.Discard}
	for _, file := range files {
		if _, err := workRunner.Run(nil, "sops", "updatekeys", "-y", file); err != nil {
			return err
		}
	}
	if _, err := workRunner.Run(nil, "git", "add", ".sops.yaml", "secrets"); err != nil {
		return err
	}
	if _, err := workRunner.Run(nil, "git", "commit", "-m", "Rekey secrets for "+request.TargetHost); err != nil {
		return err
	}
	commit, err := workRunner.Run(nil, "git", "rev-parse", "HEAD")
	if err != nil {
		return err
	}
	branch, err := r.Run(nil, "git", "-C", repository, "branch", "--show-current")
	if err != nil {
		return err
	}
	if _, err := workRunner.Run(nil, "git", "push", "origin", "HEAD:"+strings.TrimSpace(string(branch))); err != nil {
		return err
	}
	return json.NewEncoder(output).Encode(rekeyResponse{Commit: strings.TrimSpace(string(commit))})
}

func copyFile(source, destination string, mode os.FileMode) error {
	content, err := os.ReadFile(source)
	if err != nil {
		return err
	}
	if err := os.WriteFile(destination, content, mode); err != nil {
		return err
	}
	return os.Chmod(destination, mode)
}
