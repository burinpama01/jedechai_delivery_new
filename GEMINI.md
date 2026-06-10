
**กฏ:**
- ถ้า agent ทำงานไม่ได้ (เช่น ขาด API key) ให้แจ้งผู้ใช้และรอคำสั่ง ห้ามทำเอง
- ห้าม fallback ทำเองเงียบๆ โดยไม่บอกผู้ใช้
- ถ้าต้องการ spawn agent หลายตัวพร้อมกัน ให้ spawn parallel
- ถ้าไม่มี agentId ที่ตรงกับงาน ให้แจ้งผู้ใช้ก่อน ห้ามเลือกเองแบบเดา
- ห้ามเขียนทับไฟล์เดิมที่ดำเนินการเสร็จแล้ว: ห้ามแก้ไขหรือเขียนทับไฟล์แผนงาน (Plan), การออกแบบ (Design), การระดมความคิด (Brainstorming) หรือเอกสารอ้างอิงใดๆ ที่ดำเนินการเสร็จสิ้นไปแล้ว หากเป็นแผน/งานที่เสร็จแล้ว ให้ระบุสถานะในไฟล์ให้ชัดเจนว่าเสร็จสิ้น (Completed) หากมีแผนหรือแนวคิดใหม่ ให้เขียนไฟล์ใหม่แยกเป็นเวอร์ชันต่างหาก (เช่น v2, v3) เพื่อรักษาประวัติการทำงานเดิมไว้

## ภาษา

- การสนทนา: ใช้ภาษาใดก็ได้
- **รายงาน ผลสรุป แผนงาน และเอกสาร: ต้องเป็นภาษาไทยเท่านั้น**
- โค้ดและ technical term ให้ใช้ภาษาอังกฤษตามปกติ

## Caveman — โหมดตอบสั้นประหยัด token

ใช้ Caveman เมื่อต้องการลด token โดยยังคงสาระทางเทคนิคครบถ้วน

### วิธีเรียกใช้
- ผู้ใช้พิมพ์ `$caveman`, `caveman mode`, `talk like caveman` หรือ `less tokens please` ให้เปิด Caveman mode
- ผู้ใช้พิมพ์ `stop caveman`, `normal mode` หรือขอให้กลับมาตอบปกติ ให้ปิด Caveman mode
- ถ้าผู้ใช้ระบุระดับ เช่น `lite`, `full`, `ultra` ให้ปรับความสั้นตามระดับนั้น

### การเปิด/ปิดอัตโนมัติ
- วิเคราะห์บริบทและเปิด Caveman mode เองได้เมื่อคำตอบควรสั้น เช่น status update, สรุปผล, command result, diff summary, review finding หรือคำถามที่ตอบตรงได้
- ปิดหรือผ่อน Caveman mode เองได้เมื่อความชัดเจนสำคัญกว่า token เช่น planning, debugging ซับซ้อน, security, irreversible action, legal/financial/medical, API key, permission, blocker หรือผู้ใช้สับสน
- ถ้าผู้ใช้สั่งเปิด/ปิดชัดเจน ให้ทำตามคำสั่งผู้ใช้ก่อนการตัดสินใจอัตโนมัติ
- ไม่ต้องถามผู้ใช้ก่อนเปิด/ปิด Caveman mode เว้นแต่คำสั่งผู้ใช้ขัดแย้งกันหรือบริบทไม่ชัดเจนจนเสี่ยงทำงานผิด

### ระดับ
- `lite`: ตอบกระชับกว่าปกติ แต่ยังใช้ประโยคเต็ม
- `full`: ตอบสั้นมาก ใช้ fragment ได้เมื่อชัดเจน
- `ultra`: ตอบสั้นที่สุด ใช้เฉพาะข้อมูลจำเป็น ยกเว้นเรื่อง security, irreversible action, legal/financial/medical, API key, permission, blocker หรือความสับสนของผู้ใช้

### กฏการตอบเมื่อ Caveman mode เปิด
- ตอบสั้นมาก แต่ต้องไม่ตัดข้อมูลสำคัญ
- ใช้ประโยคสั้น คำตรง จุดสำคัญมาก่อน
- หลีกเลี่ยงคำเกริ่น คำชม และคำอธิบายซ้ำ
- Technical term, command, path, code และ error message ต้องคงรูปเดิม
- ถ้าเป็นเรื่อง security, irreversible action, legal/financial/medical, API key, permission, blocker หรือผู้ใช้สับสน ให้ขยายคำอธิบายเท่าที่จำเป็น
- ห้ามทำให้ข้อเท็จจริงคลุมเครือเพื่อประหยัด token

## Obsidian — บันทึกความรู้

**ทุก agent ต้องปฏิบัติตามกฏนี้โดยไม่มีข้อยกเว้น**

### เมื่อเริ่มงานโปรเจค (แก้ไข / ต่อเนื่อง)
1. ถ้ามี MCP tool `obsidian` ให้ใช้ tool นั้นอ่านโน้ตก่อน
2. ถ้าไม่มี MCP tool `obsidian` ใน tool list ให้ใช้ fallback ตรงทันที ไม่ต้องถามผู้ใช้: `C:\Users\burin\Documents\Obsidian Vault\Projects\<ชื่อโปรเจค>\`
3. ถ้าไม่มีโน้ต ให้เริ่มสร้างใหม่เมื่องานจบ

### เมื่องานจบ
บันทึกลง Obsidian ทุกครั้ง โดยเขียนลงในไฟล์ `Projects/<ชื่อโปรเจค>/log.md`:
- สิ่งที่ทำ (actions taken)
- ความคิด / เหตุผลเบื้องหลังการตัดสินใจ
- ไอเดียที่เกิดขึ้นระหว่างทำงาน
- ปัญหาที่พบและวิธีแก้

### Issue Tracking
เมื่อพบ issue ระหว่างทำงาน ให้บันทึกลงไฟล์ `Projects/<ชื่อโปรเจค>/issue.md` ใน Obsidian:
- ถ้าไฟล์ `issue.md` ยังไม่มี ให้สร้างใหม่ทันที
- บันทึก issue ให้มีรายละเอียดพอสำหรับตามแก้ เช่น วันที่, context, severity, ไฟล์/คำสั่งที่เกี่ยวข้อง, อาการ, root cause ถ้ารู้, และสถานะ
- ถ้าแก้ issue แล้ว ต้องกลับมาอัปเดต entry เดิมใน `issue.md` ด้วยผลการแก้, verification ที่รัน, วันที่แก้, และสถานะล่าสุด
- ห้ามลบ issue เก่าทิ้งเพียงเพราะแก้แล้ว ให้เปลี่ยนสถานะเป็น resolved/accepted/blocked ตามจริง

**กฏ:**
- บันทึกเฉพาะโปรเจคนั้น ห้ามปะปนข้อมูลข้ามโปรเจค
- ถ้าไม่รู้ชื่อโปรเจค ให้ถามผู้ใช้ก่อน
- ใช้ภาษาไทยในการบันทึก

## SocratiCode — ค้นหาโค้ดและวิเคราะห์ Dependency

เมื่อต้องการ **ค้นหาโค้ด** หรือ **วิเคราะห์ dependency / impact** ของโปรเจค ให้ใช้ SocratiCode ถ้ามี MCP tool ให้เรียกตรง

**กรณีที่ต้องใช้ SocratiCode:**
- ค้นหา function, class, หรือ symbol ในโค้ด
- วิเคราะห์ว่าโค้ดส่วนนี้กระทบอะไรบ้าง (impact / blast radius)
- ดู dependency graph และ circular dependency
- ติดตาม call flow ตั้งแต่ entry point

**กฏ:**
- ถ้ามี SocratiCode MCP tool ให้ใช้ก่อน
- ถ้าไม่มี SocratiCode MCP tool ใน tool list ให้ใช้ `rg`, `ctx_batch_execute`, `ctx_search`, `ctx_execute_file` ได้ทันที ไม่ต้องถามผู้ใช้
- ถ้า fallback วิเคราะห์ dependency graph, circular dependency หรือ call flow ได้ไม่ครบ ให้แจ้งข้อจำกัดในสรุป
- ห้ามอ่านไฟล์ใหญ่หรือ dump output ยาวเข้า context; ใช้ context-mode สรุป/ค้นหาแทน

## Graphify — ภาพรวมโปรเจคและ context graph (REQUIRED)

เมื่อต้องการ **ภาพรวมของโปรเจคทั้งหมด** รวมถึง codebase, docs, PDF, รูปภาพ, วิดีโอ หรือไฟล์ที่ไม่ใช่โค้ด ให้เรียกใช้ **Graphify** เสมอ ห้ามทำเองด้วยการอ่านไฟล์ทีละไฟล์

**กรณีที่ต้องใช้ Graphify:**
- เริ่มสำรวจโปรเจคใหม่ หรือกลับมาทำโปรเจคที่ context อาจล้าสมัย
- ต้องการภาพรวม architecture, modules, docs, concepts หรือความสัมพันธ์ระหว่างไฟล์
- ต้องการสรุป project context ก่อนวางแผน implementation
- ต้องการ query ความรู้จาก output เดิมใน `graphify-out/`
- ผู้ใช้พูดถึง `graphify`, `graphify.net`, graph, knowledge graph, project overview หรือ context graph

**วิธีใช้:**
```bash
graphify .
```
หรือระบุ path โปรเจค:
```bash
graphify <path/to/project>
```
ถ้ามี executable แบบ full path ให้ใช้ได้ เช่น:
```bash
C:\Users\burin\AppData\Local\Python\pythoncore-3.14-64\Scripts\graphify.exe update <path/to/project>
```

**Output ที่ต้องดู:**
- `graphify-out/report.md` — อ่านก่อนเพื่อสรุป key concepts และ connections
- `graphify-out/graph.json` — ใช้สำหรับ query หรือวิเคราะห์ graph ต่อ
- `graphify-out/graph.html` — ใช้สำหรับ visualization ถ้าต้องตรวจภาพรวมแบบ interactive

**กฏ:**
- ใช้ Graphify เมื่อต้องการสำรวจโปรเจคใหม่ หรือโปรเจคที่มีเอกสารหลายรูปแบบ
- ถ้ามี `graphify-out/` อยู่แล้ว ให้ใช้ผลเดิมก่อน แล้วค่อย `graphify update <path>` เมื่อ context อาจล้าสมัย
- ห้าม fallback อ่านไฟล์เองแทน Graphify โดยไม่บอกผู้ใช้
- ถ้า Graphify รันไม่ได้เพราะขาด dependency, permission, network, API key หรือ executable หาย ให้แจ้งผู้ใช้และรอคำสั่ง ห้าม fallback เงียบ ๆ
- ต้องเพิ่ม `graphify-out/` และ `**/graphify-out/` ใน `.gitignore` ของโปรเจค เพื่อไม่ commit output ของ Graphify
- สำหรับการค้นหา symbol/function/call flow ในโค้ด ให้ใช้ SocratiCode ตามกฎ SocratiCode ไม่ใช้ Graphify แทน เว้นแต่โจทย์ต้องการภาพรวมระดับโปรเจค

## Review — ตรวจงานหลังทำเสร็จ (REQUIRED)

หลังทำงานเสร็จทุกครั้ง ต้อง spawn agent `code_reviewer` เพื่อตรวจงานก่อนสรุปว่าเสร็จสมบูรณ์

**กฏ:**
- ต้อง spawn agent `code_reviewer` หลัง implementation / bugfix / refactor / config change / migration / deploy prep ทุกครั้ง
- การตรวจงานด้วย `code_reviewer` เป็นข้อยกเว้นจากกฎ dashboard: ให้ spawn agent โดยตรงได้ ไม่ต้องผ่าน Codex Dashboard และไม่ต้องเรียก `/api/run`
- การ spawn agent `code_reviewer` สำหรับ code review หลังทำงานเสร็จไม่ต้องขออนุญาตผู้ใช้ซ้ำ เพราะถือว่าได้รับอนุญาตตามกฎนี้แล้ว
- ห้ามใช้ `@codexreview` เป็นวิธีตรวจงานหลังทำเสร็จ ให้ใช้ agent `code_reviewer` เท่านั้น
- ให้ส่ง context ที่จำเป็นให้ `code_reviewer` เช่น เป้าหมายงาน, ไฟล์ที่แก้, test/verification ที่รัน, diff/commit ที่เกี่ยวข้อง, และข้อจำกัดที่พบ
- ถ้า agent `code_reviewer` ทำงานไม่ได้ เช่น ขาด API key, permission, dependency, environment หรือ tool ใช้งานไม่ได้ ให้บันทึก log แล้วแจ้งผู้ใช้และรอคำสั่ง ห้าม fallback ทำ review เองเงียบ ๆ
- ถ้า `code_reviewer` พบปัญหา ต้องบันทึกปัญหาและผล review ลง Obsidian log ของโปรเจคก่อน แล้วแก้ต่อจนกว่าจะผ่านหรือจนกว่าจะติด blocker
- ถ้าแก้ต่อไม่ได้เพราะขาด API key, permission, dependency, environment หรือข้อมูลจากผู้ใช้ ให้บันทึก log แล้วแจ้งผู้ใช้และรอคำสั่ง ห้าม fallback เงียบ ๆ
- ห้าม final summary ว่างานเสร็จสมบูรณ์ ถ้ายังไม่ได้ผ่าน agent `code_reviewer` หรือยังมี issue จาก review ที่ยังไม่ถูกแก้/ยังไม่ถูกระบุเป็น blocker

## การตอบสนอง

- ตอบสั้น ตรงประเด็น ไม่อธิบายเกินความจำเป็น
- ถ้าไม่แน่ใจในสิ่งที่ผู้ใช้ต้องการ ให้ถามก่อนทำ
- ห้ามแต่งข้อมูลหรือเดาข้อเท็จจริงที่ไม่รู้ — ถ้าไม่รู้ให้บอกตรงๆ

## Version Bump — ก่อน Build และ Commit (REQUIRED)

**ทุกครั้งที่จะ build หรือ commit ต้องขยับเวอร์ชั่นก่อนเสมอ ห้ามข้ามขั้นตอนนี้**

### Flutter / Mobile
แก้ `pubspec.yaml` — field `version: x.y.z+build`:
- **patch** (bug fix): เพิ่ม z เช่น `1.1.2` → `1.1.3`
- **minor** (feature): เพิ่ม y เช่น `1.1.2` → `1.2.0`
- **major** (breaking): เพิ่ม x เช่น `1.1.2` → `2.0.0`
- **build number**: เพิ่มทุกครั้งไม่ว่าจะ patch/minor/major เช่น `+43` → `+44`

### Web / Node.js
แก้ `package.json` — field `"version": "x.y.z"` ตามหลักการเดียวกัน

### กฏ
- ถ้าไม่แน่ใจว่าเป็น patch/minor/major ให้ถามผู้ใช้ก่อน
- commit message ต้องระบุเวอร์ชั่นใหม่ เช่น `chore: bump version to 1.2.0+44`
- ห้าม build หรือ commit โดยไม่ขยับเวอร์ชั่น

## ความปลอดภัย

- ถามก่อนเสมอก่อนลบไฟล์ หรือรัน command ที่อาจเป็นอันตราย
- ถามก่อนก่อนทำสิ่งที่ย้อนกลับไม่ได้

## Obsidian fallback

- หากไม่มี MCP tool `obsidian` ใน tool list ให้ค้นหา/อ่าน/เขียนโน้ตโดยตรงจาก `C:\Users\burin\Documents\Obsidian Vault\` ได้ทันที ไม่ต้องถามผู้ใช้
- ใช้ fallback นี้เฉพาะกับ Obsidian เท่านั้น และต้องอ่าน/เขียนเฉพาะ path `Projects/<ชื่อโปรเจค>/` ของโปรเจคนั้น

## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- For cross-module "how does X relate to Y" questions, prefer `graphify query "<question>"`, `graphify path "<A>" "<B>"`, or `graphify explain "<concept>"` over grep — these traverse the graph's EXTRACTED + INFERRED edges instead of scanning files
- After modifying code files in this session, run `graphify update .` to keep the graph current (AST-only, no API cost)
