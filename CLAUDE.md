# Claude Code Rules

โปรเจคนี้ใช้ `AGENTS.md` เป็น source of truth สำหรับกฎ agent, ภาษา, Obsidian, Graphify, review, version bump และความปลอดภัย

## Agent Delegation

- ถ้างานทำได้ใน session ปัจจุบัน ให้ทำตรง ไม่ต้องเรียก dashboard
- ใช้ `spawn_agent` โดยตรงสำหรับ review หรือ subtask ที่ระบบรองรับ
- ใช้ Codex Dashboard เฉพาะเมื่อผู้ใช้สั่งให้ job แสดงใน dashboard หรือจำเป็นต้องเรียก agent role จาก `C:\Users\burin\.codex\agents\`
- ห้ามใช้ port `7842` สำหรับ Codex เพราะเป็นของ Claude เท่านั้น
- ถ้าต้องเรียกผ่าน dashboard ให้ใช้ port `18889`

```bash
curl -s -X POST http://127.0.0.1:18889/api/run \
  -H "Content-Type: application/json" \
  -d "{\"agentId\":\"frontend_web\",\"prompt\":\"<งานที่ต้องทำ>\",\"cwd\":\"C:\\Users\\burin\\jedechai_delivery_new\\jedechai_delivery_new\",\"runner\":\"codex-cli\"}"
```

## Agent Files

- `agentId` ต้องตรงกับชื่อไฟล์ agent ใน `C:\Users\burin\.codex\agents\` โดยไม่รวม `.md`
- ถ้า dashboard, CLI, auth หรือ agent role ใช้งานไม่ได้ ให้แจ้งผู้ใช้และรอคำสั่ง
- ห้าม fallback ทำเองเงียบ ๆ โดยไม่บอกผู้ใช้

## Review

หลัง implementation / bugfix / refactor / config change ต้องใช้ `spawn_agent` สำหรับ `code_reviewer` ตามกฎใน `AGENTS.md`

