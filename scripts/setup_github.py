#!/usr/bin/env python3
"""Tạo labels, milestones, issues và gán người phụ trách trên GitHub từ issues.json.

Cách dùng (cần `gh auth login` trước):
    python3 scripts/setup_github.py labels
    python3 scripts/setup_github.py milestones
    python3 scripts/setup_github.py issues [--dry-run]
    python3 scripts/setup_github.py assign      # chạy sau khi các bạn chấp nhận lời mời vào repo
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = "duydat555/healthtrack"
HERE = Path(__file__).parent
ISSUES = HERE / "issues.json"
MAP_FILE = HERE / ".issue_map.json"  # key cục bộ -> số issue (không commit)

OWNERS = {
    "dat": ("Lê Duy Đạt", "duydat555"),
    "tan": ("Đặng Ngọc Tân", "ngoctan2503"),
    "thuan": ("Huỳnh Thanh Thuận", "phonEIT"),
    "tai": ("Nguyễn Văn Tài", "nguyenvantai12"),
}
PHASES = {
    0: "Phase 0 - Khởi tạo & Lập kế hoạch",
    1: "Phase 1 - Xác thực & Backend lõi",
    2: "Phase 2 - API chỉ số sức khỏe",
    3: "Phase 3 - Giao diện iOS (Flutter + Liquid Glass)",
    4: "Phase 4 - Dashboard & Nhắc nhở",
    5: "Phase 5 - Kiểm thử, Deploy & Hoàn thiện",
    6: "Phase 6 - Nghiệm thu & Đóng dự án",
}
LABELS = (
    [("epic", "5319e7", "Nhóm các task cùng mục tiêu"), ("task", "0e8a16", "Một công việc trong WBS"),
     ("bug", "d73a4a", "Lỗi"), ("change-request", "fbca04", "Thay đổi phạm vi cần CCB duyệt")]
    + [(f"phase-{n}", "1d76db", PHASES[n]) for n in PHASES]
    + [(a, c, d) for a, c, d in [
        ("backend", "b60205", "Python / FastAPI"), ("mobile", "5d4037", "Flutter / Dart"), ("ios", "000000", "Swift, Xcode, Liquid Glass"),
        ("devops", "0052cc", "Docker, CI/CD, triển khai"), ("qa", "c2185b", "Kiểm thử và chất lượng"),
        ("docs", "0075ca", "Tài liệu"), ("pm", "bfd4f2", "Quản trị dự án")]]
    + [(f"owner:{k}", "ededed", f"Người phụ trách: {v[0]}") for k, v in OWNERS.items()]
    + [("P0", "b60205", "Bắt buộc"), ("P1", "d93f0b", "Quan trọng"), ("P2", "fbca04", "Có thể trì hoãn")]
    + [(f"sp:{n}", "c5def5", f"{n} story point") for n in (1, 2, 3, 5, 8)]
)


def gh(*args, check=True):
    r = subprocess.run(["gh", *args], capture_output=True, text=True)
    if check and r.returncode != 0:
        sys.exit(f"gh {' '.join(args[:3])} lỗi: {r.stderr.strip()}")
    return r


def load():
    return json.loads(ISSUES.read_text())


def cmd_labels(_):
    for name, color, desc in LABELS:
        r = gh("label", "create", name, "-R", REPO, "-c", color, "-d", desc, "--force", check=False)
        print(("OK  " if r.returncode == 0 else "LỖI ") + name)


def cmd_milestones(_):
    for n, title in PHASES.items():
        r = gh("api", f"repos/{REPO}/milestones", "-f", f"title={title}", "-f",
               f"description=Hoàn thành khi các task P0 của phase xong và qua review", check=False)
        print(("OK  " if r.returncode == 0 else "BỎ QUA ") + title)


def render(issue, nums, epics):
    if issue["type"] == "epic":
        kids = [i for i in load() if i["type"] == "task" and i.get("epic") == issue["key"]]
        lines = "\n".join(f"- [ ] {{{{{k['key']}}}}} {k['title']} ({OWNERS[k['owner']][0]})" for k in kids)
        return f"## Mục tiêu\n{issue['goal']}\n\n## Phạm vi\n{PHASES[issue['phase']]}\n\n## Danh sách task\n{lines}\n"
    name, user = OWNERS[issue["owner"]]
    ac = "\n".join(f"- [ ] {a}" for a in issue["ac"])
    deps = "\n".join(f"- {d}" for d in issue["deps"]) or "Không có"
    ep = epics[issue["epic"]]
    return (
        f"Thuộc Epic {{{{{ep['key']}}}}}\n\n## User Story\n{issue['story']}\n\n"
        f"## Tiêu chí chấp nhận (Acceptance Criteria)\n{ac}\n\n"
        f"## Người phụ trách\n{name} (@{user})\n\n"
        f"## Story Points\n{issue['sp']}\n\n## Phụ thuộc\n{deps}\n\n"
        f"## Hướng dẫn làm\n- Nhánh gợi ý: `feat/{{{{{issue['key']}}}}}-<mô-tả>`\n"
        f"- PR ghi `Closes {{{{{issue['key']}}}}}`\n- Đạt Definition of Done: docs/10-definition-of-done.md\n"
    )


def sub(text, nums):
    return re.sub(r"\{\{(\w+)\}\}", lambda m: f"#{nums[m.group(1)]}" if m.group(1) in nums else m.group(0), text)


def labels_for(i):
    if i["type"] == "epic":
        return ["epic", f"phase-{i['phase']}", i["area"]]
    return ["task", f"phase-{i['phase']}", i["area"], f"owner:{i['owner']}", i["prio"], f"sp:{i['sp']}"]


def cmd_issues(a):
    items = load()
    epics = {i["key"]: i for i in items if i["type"] == "epic"}
    nums = json.loads(MAP_FILE.read_text()) if MAP_FILE.exists() else {}
    if a.dry_run:
        for i in items:
            print(i["key"], i["title"], labels_for(i))
        print(f"\n{len(items)} issue sẽ được tạo")
        return
    for i in items:  # lượt 1: tạo (epic trước vì đứng đầu danh sách)
        if i["key"] in nums:
            continue
        body = render(i, nums, epics)
        r = gh("issue", "create", "-R", REPO, "-t", i["title"], "-b", sub(body, nums),
               "-l", ",".join(labels_for(i)), "-m", PHASES[i["phase"]])
        nums[i["key"]] = int(r.stdout.strip().rsplit("/", 1)[1])
        MAP_FILE.write_text(json.dumps(nums))
        print(f"#{nums[i['key']]} {i['title']}")
    for i in items:  # lượt 2: thay {{key}} bằng số issue thật
        body = sub(render(i, nums, epics), nums)
        gh("issue", "edit", str(nums[i["key"]]), "-R", REPO, "-b", body)
    for i in items:  # task đã làm xong trong commit khởi tạo thì đóng lại
        if i.get("done"):
            gh("issue", "close", str(nums[i["key"]]), "-R", REPO, "-c",
               "Hoàn thành trong các commit khởi tạo dự án trên nhánh main.")
    print("Xong.")


def cmd_assign(_):
    nums = json.loads(MAP_FILE.read_text())
    for i in load():
        if i["type"] == "task" and i["key"] in nums:
            user = OWNERS[i["owner"]][1]
            r = gh("issue", "edit", str(nums[i["key"]]), "-R", REPO, "--add-assignee", user, check=False)
            print(("OK  " if r.returncode == 0 else "CHƯA ĐƯỢC ") + f"#{nums[i['key']]} -> {user}")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    s = p.add_subparsers(dest="cmd", required=True)
    for n, f in [("labels", cmd_labels), ("milestones", cmd_milestones), ("issues", cmd_issues), ("assign", cmd_assign)]:
        sp = s.add_parser(n)
        sp.set_defaults(fn=f)
        if n == "issues":
            sp.add_argument("--dry-run", action="store_true")
    a = p.parse_args()
    a.fn(a)
