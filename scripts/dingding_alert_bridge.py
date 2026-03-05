#!/usr/bin/env python3

import json
import os
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Dict, Optional, Tuple, Union
from urllib import request
from urllib.error import HTTPError, URLError

HOST = "0.0.0.0"
PORT = int(os.getenv("PORT", "18080"))

DINGTALK_MODE = os.getenv("DINGTALK_MODE", "noop").strip().lower()
DINGTALK_WEBHOOK_URL = os.getenv("DINGTALK_WEBHOOK_URL", "").strip()
DINGTALK_APP_KEY = os.getenv("DINGTALK_APP_KEY", "").strip()
DINGTALK_APP_SECRET = os.getenv("DINGTALK_APP_SECRET", "").strip()
DINGTALK_ROBOT_CODE = os.getenv("DINGTALK_ROBOT_CODE", "").strip()
DINGTALK_OPEN_CONVERSATION_ID = os.getenv("DINGTALK_OPEN_CONVERSATION_ID", "").strip()
DINGTALK_CHAT_ID = os.getenv("DINGTALK_CHAT_ID", "").strip()
DINGTALK_TARGET_MODE = os.getenv("DINGTALK_TARGET_MODE", "group").strip().lower()
DINGTALK_USER_IDS = os.getenv("DINGTALK_USER_IDS", "").strip()
DINGTALK_USER_ID_FIELD = os.getenv("DINGTALK_USER_ID_FIELD", "userIds").strip()
DINGTALK_ACCESS_TOKEN_URL = os.getenv("DINGTALK_ACCESS_TOKEN_URL", "https://api.dingtalk.com/v1.0/oauth2/accessToken").strip()
DINGTALK_SEND_API_URL = os.getenv("DINGTALK_SEND_API_URL", "https://api.dingtalk.com/v1.0/robot/groupMessages/send").strip()
DINGTALK_USER_SEND_API_URL = os.getenv("DINGTALK_USER_SEND_API_URL", "https://api.dingtalk.com/v1.0/robot/oToMessages/batchSend").strip()
DINGTALK_OPEN_CONV_QUERY_API_URL = os.getenv("DINGTALK_OPEN_CONV_QUERY_API_URL", "").strip()

_TOKEN_CACHE: Dict[str, Union[int, str]] = {"token": "", "expires_at": 0}


def http_post_json(url: str, payload: dict, headers: Optional[dict] = None) -> Tuple[int, str]:
    data = json.dumps(payload).encode("utf-8")
    req_headers = {"Content-Type": "application/json"}
    if headers:
        req_headers.update(headers)
    req = request.Request(url=url, data=data, headers=req_headers, method="POST")
    try:
        with request.urlopen(req, timeout=10) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            return resp.status, body
    except HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        return exc.code, body


def get_access_token() -> str:
    now = int(time.time())
    token = str(_TOKEN_CACHE.get("token") or "")
    expires_at = int(_TOKEN_CACHE.get("expires_at") or 0)
    if token and now < expires_at - 60:
        return token

    payload = {"appKey": DINGTALK_APP_KEY, "appSecret": DINGTALK_APP_SECRET}
    status, body = http_post_json(DINGTALK_ACCESS_TOKEN_URL, payload)
    if status < 200 or status >= 300:
        raise RuntimeError(f"failed to get access token, status={status}, body={body}")

    data = json.loads(body)
    token = data.get("accessToken") or data.get("access_token")
    expires_in = int(data.get("expireIn") or data.get("expires_in") or 7200)
    if not token:
        raise RuntimeError(f"access token missing in response: {body}")

    _TOKEN_CACHE["token"] = token
    _TOKEN_CACHE["expires_at"] = now + expires_in
    return str(token)


def build_alert_text(alert_payload: dict) -> str:
    receiver = alert_payload.get("receiver", "unknown")
    status = alert_payload.get("status", "unknown")
    alerts = alert_payload.get("alerts", [])
    lines = [f"[Infra Alert] receiver={receiver} status={status} count={len(alerts)}"]

    for alert in alerts[:5]:
        labels = alert.get("labels", {})
        annotations = alert.get("annotations", {})
        name = labels.get("alertname", "unknown")
        severity = labels.get("severity", "unknown")
        summary = annotations.get("summary", "")
        lines.append(f"- {name} ({severity}) {summary}".strip())

    if len(alerts) > 5:
        lines.append(f"... and {len(alerts) - 5} more")
    return "\\n".join(lines)


def send_webhook(text: str) -> None:
    if not DINGTALK_WEBHOOK_URL:
        raise RuntimeError("DINGTALK_WEBHOOK_URL is empty")
    payload = {"msgtype": "text", "text": {"content": text}}
    status, body = http_post_json(DINGTALK_WEBHOOK_URL, payload)
    if status < 200 or status >= 300:
        raise RuntimeError(f"webhook send failed, status={status}, body={body}")


def parse_open_conversation_id(body: str) -> str:
    try:
        data = json.loads(body)
    except json.JSONDecodeError:
        return ""

    if isinstance(data, dict):
        if data.get("openConversationId"):
            return str(data["openConversationId"])
        if isinstance(data.get("data"), dict) and data["data"].get("openConversationId"):
            return str(data["data"]["openConversationId"])
        if isinstance(data.get("result"), dict) and data["result"].get("openConversationId"):
            return str(data["result"]["openConversationId"])
    return ""


def resolve_open_conversation_id() -> str:
    if DINGTALK_OPEN_CONVERSATION_ID:
        return DINGTALK_OPEN_CONVERSATION_ID

    if not DINGTALK_CHAT_ID:
        raise RuntimeError("missing required stream env: DINGTALK_OPEN_CONVERSATION_ID or DINGTALK_CHAT_ID")

    token = get_access_token()
    headers = {
        "x-acs-dingtalk-access-token": token,
        "Authorization": f"Bearer {token}",
    }
    payload = {"chatId": DINGTALK_CHAT_ID}
    candidate_urls = [
        DINGTALK_OPEN_CONV_QUERY_API_URL,
        "https://api.dingtalk.com/v1.0/im/chat/scenegroup/openConversationId/search",
        "https://api.dingtalk.com/v1.0/im/chat/scenegroup/openConversationId/get",
    ]

    errors = []
    for url in candidate_urls:
        if not url:
            continue
        try:
            status, body = http_post_json(url, payload, headers=headers)
            if status < 200 or status >= 300:
                errors.append(f"{url}: status={status}")
                continue
            open_conv = parse_open_conversation_id(body)
            if open_conv:
                print(f"[INFO] resolved openConversationId via chatId using {url}")
                return open_conv
            errors.append(f"{url}: openConversationId not found in response")
        except (RuntimeError, URLError) as exc:
            errors.append(f"{url}: {exc}")

    raise RuntimeError("failed to resolve openConversationId from DINGTALK_CHAT_ID; " + " | ".join(errors))


def parse_user_ids(raw: str) -> list[str]:
    user_ids = [item.strip() for item in raw.split(",") if item.strip()]
    if not user_ids:
        raise RuntimeError("DINGTALK_USER_IDS is empty in stream user target mode")
    return user_ids


def send_stream_to_users(text: str, token: str) -> None:
    user_id_field = DINGTALK_USER_ID_FIELD or "userIds"
    payload = {
        "robotCode": DINGTALK_ROBOT_CODE,
        user_id_field: parse_user_ids(DINGTALK_USER_IDS),
        "msgKey": "sampleText",
        "msgParam": json.dumps({"content": text}, ensure_ascii=False),
    }
    headers = {"x-acs-dingtalk-access-token": token}
    candidate_urls = [
        DINGTALK_USER_SEND_API_URL,
        "https://api.dingtalk.com/v1.0/robot/otoMessages/batchSend",
    ]

    errors = []
    for url in candidate_urls:
        if not url:
            continue
        status, body = http_post_json(url, payload, headers=headers)
        if 200 <= status < 300:
            print(f"[INFO] stream user message sent via {url}")
            return
        errors.append(f"{url}: status={status}, body={body}")

    raise RuntimeError("stream user send failed; " + " | ".join(errors))


def send_stream(text: str) -> None:
    missing = [
        name
        for name, value in [
            ("DINGTALK_APP_KEY", DINGTALK_APP_KEY),
            ("DINGTALK_APP_SECRET", DINGTALK_APP_SECRET),
            ("DINGTALK_ROBOT_CODE", DINGTALK_ROBOT_CODE),
        ]
        if not value
    ]
    if missing:
        raise RuntimeError("missing required stream env: " + ", ".join(missing))

    token = get_access_token()
    if DINGTALK_TARGET_MODE == "user":
        send_stream_to_users(text, token)
        return

    open_conversation_id = resolve_open_conversation_id()
    payload = {
        "robotCode": DINGTALK_ROBOT_CODE,
        "openConversationId": open_conversation_id,
        "msgKey": "sampleText",
        "msgParam": json.dumps({"content": text}, ensure_ascii=False),
    }
    headers = {"x-acs-dingtalk-access-token": token}
    status, body = http_post_json(DINGTALK_SEND_API_URL, payload, headers=headers)
    if status < 200 or status >= 300:
        raise RuntimeError(f"stream group send failed, status={status}, body={body}")


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok")
            return
        self.send_response(404)
        self.end_headers()

    def do_POST(self):
        if self.path != "/alerts":
            self.send_response(404)
            self.end_headers()
            return

        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length)
        try:
            payload = json.loads(raw.decode("utf-8", errors="replace"))
        except json.JSONDecodeError:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"invalid json")
            return

        text = build_alert_text(payload)
        print(f"[INFO] mode={DINGTALK_MODE} payload_status={payload.get('status')} receiver={payload.get('receiver')}")

        try:
            if DINGTALK_MODE == "noop":
                print("[INFO] noop mode, skip delivery")
            elif DINGTALK_MODE == "webhook":
                send_webhook(text)
                print("[INFO] webhook sent")
            elif DINGTALK_MODE == "stream":
                send_stream(text)
                print("[INFO] stream message sent")
            else:
                raise RuntimeError(f"unsupported DINGTALK_MODE={DINGTALK_MODE}")
        except (RuntimeError, HTTPError, URLError) as exc:
            print(f"[ERROR] delivery failed: {exc}")
            self.send_response(500)
            self.end_headers()
            self.wfile.write(str(exc).encode("utf-8", errors="replace"))
            return

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")

    def log_message(self, fmt, *args):
        return


if __name__ == "__main__":
    print(f"[INFO] dingding bridge listening on {HOST}:{PORT}, mode={DINGTALK_MODE}")
    server = HTTPServer((HOST, PORT), Handler)
    server.serve_forever()
