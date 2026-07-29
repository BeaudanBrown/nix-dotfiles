package main

import (
	"bufio"
	"strings"
	"testing"
)

func TestRemovableDisksFiltersUnsafeDevices(t *testing.T) {
	input := `{"blockdevices":[
		{"path":"/dev/nvme0n1","name":"nvme0n1","size":1000000000000,"model":"Internal","serial":"a","tran":"nvme","rm":false,"type":"disk","mountpoints":[null]},
		{"path":"/dev/sdb","name":"sdb","size":68719476736,"model":"USB","serial":"b","tran":"usb","rm":true,"type":"disk","mountpoints":[null]},
		{"path":"/dev/sdc","name":"sdc","size":17179869184,"model":"Small","serial":"c","tran":"usb","rm":true,"type":"disk","mountpoints":[null]}
	]}`
	devices, err := removableDisks([]byte(input))
	if err != nil {
		t.Fatal(err)
	}
	if len(devices) != 1 || devices[0].Path != "/dev/sdb" {
		t.Fatalf("unexpected devices: %#v", devices)
	}
}

func TestConfirmDefaultsNoForDestructiveAction(t *testing.T) {
	var output strings.Builder
	answer, err := (prompt{bufio.NewReader(strings.NewReader("\n")), &output}).confirm("Erase?", false)
	if err != nil {
		t.Fatal(err)
	}
	if answer {
		t.Fatal("blank destructive confirmation must be false")
	}
	if !strings.Contains(output.String(), "[y/N]") {
		t.Fatalf("missing default-no marker: %q", output.String())
	}
}

func TestRenderWiFiProfileIsPortable(t *testing.T) {
	profile := renderWiFiProfile(wifiProfile{ID: "installer-home", SSID: "home", KeyMgmt: "wpa-psk", PSK: "correct horse"})
	for _, expected := range []string{"ssid=home", "psk=correct horse", "method=auto"} {
		if !strings.Contains(profile, expected) {
			t.Fatalf("profile missing %q: %s", expected, profile)
		}
	}
	for _, forbidden := range []string{"interface-name", "mac-address", "seen-bssids"} {
		if strings.Contains(profile, forbidden) {
			t.Fatalf("profile contains hardware binding %q", forbidden)
		}
	}
}

func TestAskPasswordUsesExplicitTestPassword(t *testing.T) {
	t.Setenv("FLEET_INSTALLER_TEST_LUKS_PASSWORD", "correct horse")
	password, err := askPassword(nil, "USB LUKS passphrase")
	if err != nil || password != "correct horse" {
		t.Fatalf("unexpected password result: %q / %v", password, err)
	}
}

func TestUSBLayoutUsesSelectedDiskAndLUKS(t *testing.T) {
	layout := usbLayout("/dev/disk/by-id/usb-test", "/tmp/key")
	for _, expected := range []string{"/dev/disk/by-id/usb-test", `type = "luks"`, `format = "ext4"`, "INSTALLER_LUKS", "nodiscard"} {
		if !strings.Contains(layout, expected) {
			t.Fatalf("layout missing %q", expected)
		}
	}
}
