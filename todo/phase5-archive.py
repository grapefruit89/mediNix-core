#!/usr/bin/env python3
"""Phase 5: Self-Archive. Verschiebt den aktuellen Chat nach done/<chat-id>/."""
import json, pathlib, datetime, shutil, collections, sys

TODO = pathlib.Path("/home/moritz/repos/mediNix-core/todo")

def main():
    # 1. Chat-ID ableiten
    data = json.loads((TODO / "_input/chat.json").read_text(encoding="utf-8"))
    if not data:
        sys.exit("❌ _input/chat.json ist leer")
    first = data[0]
    group_id = first.get("chatGroupId", "unknown")
    date = (first.get("created_at") or "1970-01-01")[:10]

    topics_path = TODO / "_index/topics.json"
    top_topic = "chat"
    if topics_path.exists():
        topics = json.loads(topics_path.read_text(encoding="utf-8"))
        counter = collections.Counter()
        for msg_topics in topics.get("message_to_topics", {}).values():
            for t in msg_topics:
                counter[t] += 1
        if counter:
            top_topic = counter.most_common(1)[0][0]

    chat_id = f"{date}_{group_id[:8]}_{top_topic}"

    # 2. Zielordner
    dest = TODO / "done" / chat_id
    if dest.exists():
        sys.exit(f"❌ done/{chat_id} existiert bereits")

    # 3. Blöcke zählen (vor dem Verschieben)
    block_files = list((TODO / "blocks").glob("*.json"))
    verdicts = collections.Counter()
    for bf in block_files:
        b = json.loads(bf.read_text(encoding="utf-8"))
        for d in b.get("decisions", []):
            verdicts[d.get("verdict", "unknown")] += 1

    # 4. Verschieben
    dest.mkdir(parents=True)
    for name in ["_input", "_index", "blocks"]:
        shutil.move(str(TODO / name), str(dest / name.lstrip("_")))
    shutil.move(str(TODO / "plan.json"), str(dest / "plan.json"))
    shutil.move(str(TODO / "decisions.md"), str(dest / "decisions.md"))

    # 5. meta.json
    meta = {
        "chat_id": chat_id,
        "chat_group_id": group_id,
        "total_messages": len(data),
        "blocks_count": len(block_files),
        "decisions_count": sum(verdicts.values()),
        "verdict_summary": dict(verdicts),
        "archived_at": datetime.datetime.now().isoformat(),
    }
    (dest / "meta.json").write_text(
        json.dumps(meta, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    # 6. todo/ frisch
    (TODO / "_input").mkdir()
    (TODO / "_index").mkdir()
    (TODO / "blocks").mkdir()
    (TODO / "plan.json").write_text(json.dumps({
        "generated_at": None,
        "source_chat": "/home/moritz/repos/mediNix-core/todo/_input/chat.json",
        "blocks_processed": [],
        "summary": {"decided": 0, "proposed": 0, "rejected": 0, "open": 0},
        "todos": [],
    }, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (TODO / "decisions.md").write_text(
        "# Entscheidungen aus dem Chat\n\n> Wird vom Agenten nach Phase 4 befüllt.\n",
        encoding="utf-8",
    )

    print(f"✅ Chat {chat_id} -> done/{chat_id}/")
    print(f"   {len(block_files)} Blöcke, {sum(verdicts.values())} Entscheidungen")
    print(f"   todo/ bereit für den nächsten Chat")

if __name__ == "__main__":
    main()
