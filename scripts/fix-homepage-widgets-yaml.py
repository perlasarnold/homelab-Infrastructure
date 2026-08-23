import paramiko
import time
import base64

BULAKAN_IP = "192.168.1.25"
PASSWORD = "***REMOVED***"
VMID = "116"

WIDGETS_YAML = """---
- search:
    provider: duckduckgo
    target: _blank

- clock:
    format: "h:mm:ss A"

- greeting:
    text_size: xl

- resources:
    cpu: true
    memory: true
    disk: /
"""

def run_ssh(cmd, timeout=300):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(BULAKAN_IP, username="root", password=PASSWORD, timeout=15)
        print(f"\n$ {cmd}")
        stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
        out = stdout.read().decode("utf-8", errors="replace").strip()
        err = stderr.read().decode("utf-8", errors="replace").strip()
        code = stdout.channel.recv_exit_status()
        if out:
            print(out[:1000])
        if err and code != 0:
            print(f"STDERR: {err[:1000]}")
        return code, out, err
    finally:
        client.close()

def main():
    print("==================================================================")
    print(" Updating Header Widgets in Homepage (Fixing Missingclock)")
    print("==================================================================")

    b64_widgets = base64.b64encode(WIDGETS_YAML.encode("utf-8")).decode("ascii")
    run_ssh(f"pct exec {VMID} -- bash -c 'echo \"{b64_widgets}\" | base64 -d > /opt/homepage/config/widgets.yaml'")
    run_ssh(f"pct exec {VMID} -- bash -c 'cd /opt/homepage && docker-compose restart'")

    time.sleep(3)
    print("\n==================================================================")
    print(" SUCCESS: Header Widgets Updated!")
    print("==================================================================")

if __name__ == "__main__":
    main()
