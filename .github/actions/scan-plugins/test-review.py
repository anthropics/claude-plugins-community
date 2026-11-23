#!/usr/bin/env python3
"""Tests for scripts/review.py and scripts/scan.sh against a fake API. No network."""

import http.server
import json
import os
import subprocess
import sys
import tempfile
import threading

HERE = os.path.dirname(os.path.abspath(__file__))
REVIEW = os.path.join(HERE, "scripts", "review.py")
GOOD = {
    "passes": True,
    "summary": "s",
    "violations": "",
    "may_make_external_network_calls": False,
    "may_download_additional_software": False,
}


def message(text, stop="end_turn", extra=()):
    return {"stop_reason": stop, "content": [*extra, {"type": "text", "text": text}]}


class Api(http.server.BaseHTTPRequestHandler):
    requests, answer, statuses = [], None, []

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["content-length"])))
        Api.requests.append((self.path, dict(self.headers), body))
        status, out = 200, {"access_token": "tok"}
        if self.path == "/v1/messages":
            status = Api.statuses.pop(0) if Api.statuses else 200
            out = Api.answer if status == 200 else {"error": {"message": "refused\n::error::x"}}
        raw = out if isinstance(out, bytes) else json.dumps(out).encode()
        self.send_response(status)
        if 300 <= status < 400:
            self.send_header("location", "/elsewhere")
        self.send_header("content-length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def log_message(self, *args):
        pass


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Api)
threading.Thread(target=server.serve_forever, daemon=True).start()
tmp = tempfile.mkdtemp()
prompt = os.path.join(tmp, "prompt.md")
token = os.path.join(tmp, "jwt")
open(prompt, "w").write("POLICY")
open(token, "w").write("the-jwt\n")
ENV = {
    "PATH": os.environ["PATH"],
    "HOME": tmp,
    "ANTHROPIC_BASE_URL": f"http://127.0.0.1:{server.server_port}",
    "ANTHROPIC_FEDERATION_RULE_ID": "fdrl_x",
    "ANTHROPIC_ORGANIZATION_ID": "org",
    "ANTHROPIC_SERVICE_ACCOUNT_ID": "svac_x",
    "ANTHROPIC_IDENTITY_TOKEN_FILE": token,
    "SCAN_MODEL": "m",
    "SCAN_TIMEOUT_SECS": "20",
}
passed = failed = 0


def check(name, ok, detail=""):
    global passed, failed
    if ok:
        passed += 1
    else:
        failed += 1
        print(f"FAIL {name} {detail}")


def git(repo, *args, data=None):
    env = {"PATH": os.environ["PATH"], "HOME": tmp, "GIT_CONFIG_GLOBAL": "/dev/null"}
    args = ["git", "-C", repo, "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false", *args]
    return subprocess.run(args, env=env, input=data, capture_output=True, check=True).stdout.decode().strip()


def commit(files, links=(), submodule=None, mode="100644"):
    """A repository with these files, and its commit. Written with plumbing, so any path works."""
    repo = tempfile.mkdtemp(dir=tmp)
    git(repo, "init", "-q")
    for path, data in files.items():
        oid = git(repo, "hash-object", "-w", "--stdin", data=data)
        git(repo, "update-index", "--add", "--cacheinfo", f"{mode},{oid},{path}")
    for path, to in links:
        oid = git(repo, "hash-object", "-w", "--stdin", data=to.encode())
        git(repo, "update-index", "--add", "--cacheinfo", f"120000,{oid},{path}")
    if submodule:
        git(repo, "update-index", "--add", "--cacheinfo", f"160000,{'1' * 40},{submodule}")
    git(repo, "commit", "-q", "-m", "x")
    return repo, git(repo, "rev-parse", "HEAD")


def review(files, subdir="", answer=None, statuses=(), env=None, **kw):
    repo, sha = commit(files, **kw)
    Api.requests, Api.statuses = [], list(statuses)
    Api.answer = message(json.dumps(GOOD)) if answer is None else answer
    args = [sys.executable, "-I", REVIEW, repo, sha, subdir, prompt]
    run = subprocess.run(args, env={**ENV, **(env or {})}, capture_output=True, text=True)
    sent = next((b for p, _, b in Api.requests if p == "/v1/messages"), None)
    return run, sent


def shown(sent):
    return {f["path"]: f for f in json.loads(sent["messages"][0]["content"])["files"]}


def refused(name, run, words=""):
    check(name, run.returncode == 3 and not run.stdout and words in run.stderr, repr((run.returncode, run.stdout, run.stderr)))
    check(name + ": one line", run.stderr.count("\n") == 1, repr(run.stderr))


ONE = {"a.md": b"hello"}

# the request
run, sent = review(ONE)
check("verdict", run.returncode == 0 and json.loads(run.stdout) == GOOD, run.stderr)
check("no tools", not {"tools", "tool_choice", "mcp_servers"} & set(sent))
check("policy first", sent["system"].startswith("POLICY\n"))
check("exchange", Api.requests[0][0] == "/v1/oauth/token" and Api.requests[0][2]["assertion"] == "the-jwt")
check("bearer", Api.requests[1][1].get("authorization", Api.requests[1][1].get("Authorization")) == "Bearer tok")
check("token not in the request", "the-jwt" not in json.dumps(sent))
run, sent = review(ONE, env={"ANTHROPIC_FEDERATION_RULE_ID": "", "ANTHROPIC_API_KEY": "k"})
check("api key", run.returncode == 0 and [p for p, _, _ in Api.requests] == ["/v1/messages"])

# what is shown
run, sent = review({"x/a.md": b"in", "b.md": b"out", "x/.hid/y.sh": b"z"}, subdir="x/")
check("subdir only", set(shown(sent)) == {"a.md", ".hid/y.sh"}, str(sent))
run, sent = review({"a.sh": b"echo \xff\xfe"})
check("not UTF-8 is shown", shown(sent)["a.sh"]["text"] == "echo \\xff\\xfe")
text = "a\u200bb\u202ec\U000e0041d\ufe0fe\u0085f"
run, sent = review({"a.md": text.encode()})
raw = sent["messages"][0]["content"]
check("invisible text is escaped", all(ord(c) < 127 for c in raw) and shown(sent)["a.md"]["text"] == text, raw)
run, sent = review({"a\"]}\n{.md": b'"}]}'})
check("names and text stay inside JSON", list(shown(sent).values()) == [{"path": "a\"]}\n{.md", "text": '"}]}'}])
run, sent = review({"i.png": b"\x89PNG\r\n\x1a\n\x00", "a.md": b"x"})
check("image is listed", set(shown(sent)["i.png"]) == {"path", "not_shown"})
run, sent = review({"i.png": b"#!/bin/sh\n"})
check("text under an image's name is shown", shown(sent)["i.png"]["text"] == "#!/bin/sh\n")
run, sent = review({"d/a.md": b"x", "b.md": b"y"}, links=[("l", "d/a.md"), ("m", "d"), ("d/up", "../b.md"), ("n", "./l")])
check("symlinks inside", shown(sent)["l"] == {"path": "l", "symlink": "d/a.md"} and len(shown(sent)) == 6, run.stderr)

# what stops the review
for name, data in {"a.so": b"\x7fELF\x00", "a.wasm": b"\x00asm", "a.sh": b"x\x00", "b.png": b"\x00\x01", "noext": b"\x00"}.items():
    run, sent = review({name: data})
    refused("binary " + name, run, "not text")
    check("nothing sent for " + name, not Api.requests)
links = {
    "absolute": ("l", "/proc/self/environ"),
    "outside": ("l", "../evil.md"),
    "outside by a longer way": ("d/l", "../../evil.md"),
    "missing": ("l", "none.md"),
    "dots inside": ("l", "d/../d/a.md"),
    "git folder": ("l", ".git/config"),
    "empty part": ("l", "d//a.md"),
}
for name, link in links.items():
    refused("symlink " + name, review({"p/d/a.md": b"x", "evil.md": b"y"}, subdir="p", links=[("p/" + link[0], link[1])])[0], "symlink")
refused("symlink through a symlink", review({"d/a.md": b"x"}, links=[("m", "d"), ("l", "m/a.md")])[0], "symlink")
refused("symlink through a symlinked folder", review({"d/e/a.md": b"x"}, links=[("m", "d/e"), ("l", "m/../a.md")])[0], "symlink")
refused("submodule", review(ONE, submodule="sub")[0], "submodule")
refused("LFS", review({"SKILL.md": b"version https://git-lfs.github.com/spec/v1\noid sha256:0\n"})[0], "Git LFS")
for text in (b"version https://hawser.github.com/spec/v1\noid sha256:0\nsize 1\n", b"\n version x\r\n  oid sha256:0\r\n"):
    refused("LFS, other forms", review({"SKILL.md": text})[0], "Git LFS")
refused("filter inside", review({"a.md": b"x", ".gitattributes": b"* text=auto\n*.md  filter=lfs\n"})[0], "filter")
refused("filter above", review({"p/q/a.md": b"x", "p/.GitAttributes": b"* filter=x"}, subdir="p/q")[0], "filter")
run, sent = review({"p/a.md": b"x", "q/.gitattributes": b"* filter=x", ".gitattributes": b"* text=auto"}, subdir="p")
check("filter elsewhere", run.returncode == 0, run.stderr)
refused("case", review({"A/x": b"x", "a/y": b"y"})[0], "only in case")
refused("executable image", review({"t.gif": b"GIF89a=1;\n\x00"}, mode="100755")[0], "executable")
refused("binary without NUL", review({"a": bytes(range(1, 256))})[0], "not text")
run, sent = review({"::error::\nx\u202e": b"\x00"})
refused("hostile name in the reason", run, "::error::?x?")
run, sent = review({"a.txt": b"x" * 1_500_001})
refused("too large", run, "too much for one review")
check("nothing sent when too large", not Api.requests)
refused("no such folder", review(ONE, subdir="nope")[0])
refused("file as folder", review(ONE, subdir="a.md")[0], "not a folder")

# answers that are not a verdict
bad = {
    "text": message("passes: true"),
    "wrapped": message("x" + json.dumps(GOOD)),
    "fenced": message("```json\n" + json.dumps(GOOD) + "\n```"),
    "string passes": message(json.dumps({**GOOD, "passes": "true"})),
    "number passes": message(json.dumps({**GOOD, "passes": 1})),
    "missing field": message(json.dumps({k: v for k, v in GOOD.items() if k != "violations"})),
    "extra field": message(json.dumps({**GOOD, "x": 1})),
    "repeated key": message(json.dumps(GOOD)[:-1] + ', "passes": true}'),
    "cut off": message(json.dumps(GOOD), stop="max_tokens"),
    "refusal": message(json.dumps(GOOD), stop="refusal"),
    "two texts": message(json.dumps(GOOD), extra=[{"type": "text", "text": "{}"}]),
    "tool call": message(json.dumps(GOOD), extra=[{"type": "tool_use", "name": "x"}]),
    "no content": {"stop_reason": "end_turn"},
    "not an object": [],
    "not JSON": b"<html>",
    "deep": message("[" * 200_000),
}
for name, answer in bad.items():
    refused(name, review(ONE, answer=answer)[0])
run, sent = review(ONE, answer=message(json.dumps(GOOD), extra=[{"type": "thinking", "thinking": "x"}]))
check("thinking is allowed", run.returncode == 0, run.stderr)
run, sent = review(ONE, statuses=[400])
refused("HTTP 400", run, "HTTP 400: refused?")
check("HTTP 400 is not retried", len(Api.requests) == 2)
run, sent = review(ONE, statuses=[302])
refused("redirect", run, "HTTP 302")
check("no redirect followed", all(p != "/elsewhere" for p, _, _ in Api.requests))
run, sent = review(ONE, statuses=[529])
check("retry", run.returncode == 0, run.stderr)
refused("no key", review(ONE, env={"ANTHROPIC_FEDERATION_RULE_ID": ""})[0])

# scan.sh, with git sent to a local repository
shim = os.path.join(tmp, "bin")
os.mkdir(shim)
real = subprocess.run(["sh", "-c", "command -v git"], capture_output=True, text=True).stdout.strip()


def scan(files, answer, fail="true", statuses=()):
    repo, sha = commit(files)
    git(repo, "config", "uploadpack.allowAnySHA1InWant", "true")
    with open(os.path.join(shim, "git"), "w") as f:
        f.write(f'#!/bin/bash\na=(); for x in "$@"; do [[ "$x" == https://github.com/o/r ]] && x="file://{repo}"; a+=("$x"); done\nexec {real} "$' + '{a[@]}"\n')
    os.chmod(os.path.join(shim, "git"), 0o755)
    market = os.path.join(tmp, "targets.json")
    json.dump({"plugins": [{"name": "p", "source": {"source": "url", "url": "https://github.com/o/r", "sha": sha}}]}, open(market, "w"))
    out = os.path.join(tmp, "out")
    open(out, "w").close()
    Api.requests, Api.statuses, Api.answer = [], list(statuses), answer
    env = {
        **ENV,
        "PATH": shim + ":" + ENV["PATH"],
        "ACTION_PATH": HERE,
        "VALIDATE_LIB": os.path.join(HERE, "../validate-plugins/lib/common.sh"),
        "MARKETPLACE_PATH": market,
        "BASE_REF": "none",
        "ALLOWED_HOSTS": "github.com",
        "FAIL_ON_FINDINGS": fail,
        "POLICY_PROMPT": prompt,
        "GITHUB_OUTPUT": out,
        "GITHUB_STEP_SUMMARY": os.path.join(tmp, "summary"),
    }
    run = subprocess.run(["bash", os.path.join(HERE, "scripts", "scan.sh")], env=env, cwd=tmp, stdin=subprocess.DEVNULL, capture_output=True, text=True)
    lines = dict(x.split("=", 1) for x in open(out).read().splitlines() if "=" in x)
    return run, lines


run, out = scan(ONE, message(json.dumps(GOOD)))
check("scan: pass", run.returncode == 0 and out["result"] == "pass" and json.loads(out["scanned"])[0]["passes"] is True, run.stdout + run.stderr)
run, out = scan(ONE, message(json.dumps({**GOOD, "passes": False, "violations": "a\n::error::b"})))
check("scan: violation", run.returncode == 1 and out["result"] == "fail" and json.loads(out["failed"]) == ["p"], run.stdout)
check("scan: no command from the model", "\n::error::b" not in run.stdout)
for name, args in {"no verdict": (ONE, message("x")), "binary": ({"a": b"\x00"}, message(json.dumps(GOOD)))}.items():
    run, out = scan(*args)
    check("scan: not assessed fails, " + name, run.returncode == 1 and out["result"] == "fail" and json.loads(out["scanned"]) == [], run.stdout)
    run, out = scan(*args, fail="false")
    check("scan: only a warning by default, " + name, run.returncode == 0 and json.loads(out["scanned"]) == [] and "not assessed" in run.stdout, run.stdout)
run, out = scan(ONE, None, statuses=[400])
check("scan: the API's words are shown, as one line", "HTTP 400: refused?::error" not in run.stdout and "answered HTTP 400" in run.stdout and "\n::error::x" not in run.stdout, run.stdout)
check("scan: the token is only masked", all(x.startswith("::add-mask::") for x in run.stdout.splitlines() if "the-jwt" in x))

print(f"test-review: {passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
