"""
server_health.py — Server Health Analysis & Remediation
Run interactively in Jupyter Lab or headlessly via GitHub Actions:

  # Headless (GitHub Actions):
  python notebooks/server_health.py --host $DEBIAN_VM_IP --key /tmp/id_rsa

  # Interactive: open in Jupyter Lab and run cells
"""

import argparse
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

# ── Optional imports (install via: pip install paramiko rich) ─────────────────
try:
    import paramiko
    HAS_PARAMIKO = True
except ImportError:
    HAS_PARAMIKO = False

try:
    from rich.console import Console
    from rich.table import Table
    console = Console()
except ImportError:
    class Console:
        def print(self, *a, **kw): print(*a)
    console = Console()

# ─────────────────────────────────────────────────────────────────────────────
# Section 1 — SSH Connection
# ─────────────────────────────────────────────────────────────────────────────

def get_ssh_client(host: str, user: str, key_path: str) -> "paramiko.SSHClient":
    """Create an authenticated SSH connection. Key is loaded from path — never hardcoded."""
    if not HAS_PARAMIKO:
        raise ImportError("Install paramiko: pip install paramiko")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.RejectPolicy())  # strict — no auto-accept
    client.connect(hostname=host, username=user, key_filename=key_path, timeout=10)
    return client

def run_remote(client, cmd: str) -> str:
    """Run a command on the remote host and return stdout."""
    _, stdout, stderr = client.exec_command(cmd, timeout=30)
    rc = stdout.channel.recv_exit_status()
    output = stdout.read().decode().strip()
    if rc != 0:
        err = stderr.read().decode().strip()
        raise RuntimeError(f"Command failed (rc={rc}): {err}")
    return output

# ─────────────────────────────────────────────────────────────────────────────
# Section 2 — Health Checks
# ─────────────────────────────────────────────────────────────────────────────

def check_disk(client) -> dict:
    """Returns disk usage % for root filesystem."""
    out = run_remote(client, "df / --output=pcent | tail -1 | tr -d ' %'")
    pct = int(out)
    status = "CRITICAL" if pct >= 90 else "WARNING" if pct >= 80 else "OK"
    return {"metric": "Disk /", "value": f"{pct}%", "status": status}

def check_ram(client) -> dict:
    """Returns RAM usage %."""
    out = run_remote(client, "free | awk '/^Mem:/ {printf \"%.0f\", $3/$2 * 100}'")
    pct = int(out)
    status = "CRITICAL" if pct >= 90 else "WARNING" if pct >= 85 else "OK"
    return {"metric": "RAM", "value": f"{pct}%", "status": status}

def check_cpu(client) -> dict:
    """Returns 5-minute load average as % of CPU cores."""
    out = run_remote(client, "awk '{print $2}' /proc/loadavg")
    cores_str = run_remote(client, "nproc")
    pct = int(float(out) * 100 / int(cores_str))
    status = "CRITICAL" if pct >= 95 else "WARNING" if pct >= 80 else "OK"
    return {"metric": "CPU (5m avg)", "value": f"{pct}%", "status": status}

def check_docker_services(client) -> list:
    """Check all deployed compose stacks for stopped containers."""
    results = []
    stacks_raw = run_remote(client, "find /opt/homelab/stacks -name docker-compose.yml 2>/dev/null")
    for compose_path in stacks_raw.splitlines():
        name = Path(compose_path).parent.name
        try:
            expected = int(run_remote(client, f"docker compose -f {compose_path} config --services | wc -l"))
            running  = int(run_remote(client, f"docker compose -f {compose_path} ps --status running -q 2>/dev/null | wc -l"))
            status = "OK" if running == expected else "WARNING" if running > 0 else "CRITICAL"
            results.append({"metric": f"Stack: {name}", "value": f"{running}/{expected} containers", "status": status})
        except Exception as e:
            results.append({"metric": f"Stack: {name}", "value": f"Check failed: {e}", "status": "UNKNOWN"})
    return results

# ─────────────────────────────────────────────────────────────────────────────
# Section 3 — Auto-Remediation Actions
# ─────────────────────────────────────────────────────────────────────────────

def remediate_disk(client) -> str:
    """Free disk space by pruning Docker and compressing logs."""
    console.print("[yellow]ACTION: Pruning Docker images/volumes and compressing logs...[/yellow]")
    run_remote(client, "docker image prune -af --filter 'until=48h'")
    run_remote(client, "docker volume prune -f")
    run_remote(client, "find /var/log -name '*.log' -mtime +7 -exec gzip -f {} \\;")
    new_pct = int(run_remote(client, "df / --output=pcent | tail -1 | tr -d ' %'"))
    return f"Disk after cleanup: {new_pct}%"

def remediate_ram(client) -> str:
    """Drop page cache to reclaim RAM."""
    console.print("[yellow]ACTION: Dropping page cache to free RAM...[/yellow]")
    run_remote(client, "sync && echo 1 > /proc/sys/vm/drop_caches")
    new_pct = int(run_remote(client, "free | awk '/^Mem:/ {printf \"%.0f\", $3/$2 * 100}'"))
    return f"RAM after cache drop: {new_pct}%"

def remediate_service(client, compose_path: str) -> str:
    """Restart a stopped Docker Compose stack."""
    name = Path(compose_path).parent.name
    console.print(f"[yellow]ACTION: Restarting stack {name}...[/yellow]")
    run_remote(client, f"docker compose -f {compose_path} up -d --remove-orphans")
    return f"Stack {name} restarted"

# ─────────────────────────────────────────────────────────────────────────────
# Section 4 — Report
# ─────────────────────────────────────────────────────────────────────────────

def print_report(metrics: list, actions: list):
    """Pretty-print health report."""
    table = Table(title=f"Server Health Report — {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    table.add_column("Metric", style="cyan", no_wrap=True)
    table.add_column("Value")
    table.add_column("Status")

    STATUS_STYLE = {"OK": "green", "WARNING": "yellow", "CRITICAL": "red", "UNKNOWN": "dim"}
    for m in metrics:
        style = STATUS_STYLE.get(m["status"], "white")
        table.add_row(m["metric"], m["value"], f"[{style}]{m['status']}[/{style}]")

    console.print(table)

    if actions:
        console.print("\n[bold]Actions taken:[/bold]")
        for a in actions:
            console.print(f"  ✓ {a}")

    # Write JSON report for CI artifact upload
    report = {"timestamp": datetime.now().isoformat(), "metrics": metrics, "actions": actions}
    report_path = Path("/tmp/health-report.json")
    report_path.write_text(json.dumps(report, indent=2))
    console.print(f"\n[dim]Report written to {report_path}[/dim]")

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Homelab server health check & auto-remediation")
    parser.add_argument("--host",     required=True,  help="VM IP address")
    parser.add_argument("--user",     default="debian", help="SSH user")
    parser.add_argument("--key",      required=True,  help="Path to SSH private key (never hardcoded)")
    parser.add_argument("--remediate", action="store_true", help="Auto-fix problems found")
    args = parser.parse_args()

    client = get_ssh_client(args.host, args.user, args.key)
    metrics = []
    actions = []

    try:
        # Gather metrics
        metrics.append(check_disk(client))
        metrics.append(check_ram(client))
        metrics.append(check_cpu(client))
        metrics.extend(check_docker_services(client))

        # Auto-remediate if requested
        if args.remediate:
            disk_m = next(m for m in metrics if m["metric"] == "Disk /")
            if disk_m["status"] != "OK":
                actions.append(remediate_disk(client))

            ram_m = next(m for m in metrics if m["metric"] == "RAM")
            if ram_m["status"] != "OK":
                actions.append(remediate_ram(client))

            stacks_raw = run_remote(client, "find /opt/homelab/stacks -name docker-compose.yml 2>/dev/null")
            for compose_path in stacks_raw.splitlines():
                svc_m = next((m for m in metrics if f"/{Path(compose_path).parent.name}" in m["metric"]), None)
                if svc_m and svc_m["status"] != "OK":
                    actions.append(remediate_service(client, compose_path))

        print_report(metrics, actions)

        # Exit non-zero if any CRITICAL (lets GitHub Actions mark the run as failed)
        has_critical = any(m["status"] == "CRITICAL" for m in metrics)
        sys.exit(1 if has_critical else 0)

    finally:
        client.close()


if __name__ == "__main__":
    main()
