# ผลตรวจ redesign หน้าคนขับ — 20 กันยายน 2026

สถานะ: ต้องแก้ P2 / Major 1 จุดก่อนถือว่าผ่าน responsive ตามแผน

ผลตรวจจาก main: ชุดเทสต์เดิม 229/229 ผ่านก่อนเพิ่ม probe; รัน probe ซ้ำยืนยันผ่าน 2 / ไม่ผ่าน 2; flutter analyze --no-pub มี 0 error, 1 warning, 663 info และ exit 1 (warning: grossCollect ไม่ถูกใช้ที่ driver_job_detail_screen.dart:283) ไม่ใช่ analyze สะอาด

บันทึก Obsidian log.md, current.md, log-index.md, issue.md และ issue-index.md แล้ว เปิด ISSUE-20260920-003; ยังไม่มีการแก้โค้ดระบบ/build/commit/deploy หรือสร้าง skill ใหม่

## ข้อพบยืนยัน: P2 / Major — แผงเลือกประเภทงานล้นจอแนวนอน

- ไฟล์: `jedechai_delivery_new/lib/apps/driver/screens/driver_service_type_settings.dart:109`
- ส่วนที่เกี่ยวข้อง: บรรทัด 109–160 เป็น Column ไม่มี scroll; บรรทัด 191–195 เพิ่ม padding แนวตั้ง 13 ต่อด้านของแต่ละแถว รวม 4 ประเภทงาน
- ผลกระทบ: ปุ่มบันทึกอยู่ท้ายแผงและตกออกนอกพื้นที่แสดงผล ผู้ใช้เลื่อนลงไปกดไม่ได้
- แผนที่เกี่ยวข้อง: `Plan/UI_Redesign_Responsive_Addendum_v1.html` กำหนดรองรับมือถือแนวนอนและเลื่อนเนื้อหาเมื่อจอเตี้ย
- วิธีแก้ที่เสนอ: จำกัดความสูงแผงตาม viewport แล้วให้รายการเลื่อนได้ หรือห่อเนื้อหาใน scroll โดยคงปุ่มบันทึกให้เข้าถึงได้

## หลักฐานทดสอบ

คำสั่ง:

```text
C:\flutter\bin\flutter.bat test test/redesign_review_probe_test.dart --no-pub --reporter expanded
```

ไฟล์ probe: `jedechai_delivery_new/test/redesign_review_probe_test.dart`

เงื่อนไข: Locale ไทย, AppTheme.lightTheme ปัจจุบัน, text scale 1.0, devicePixelRatio 1.0, Material ancestor เหมือนการใช้ sheet

| กรณี | ผล |
|---|---|
| Wallet 640×360 สถานะไม่มีผู้ใช้ | ผ่าน |
| Service settings ใหม่ 640×360 | RenderFlex overflowed by 170 pixels on the bottom |
| Service settings rendering subtree ก่อน redesign จาก HEAD ที่ 640×480 ภายใต้ theme ปัจจุบัน | ผ่าน |
| Service settings ใหม่ 640×480 | RenderFlex overflowed by 50 pixels on the bottom |

ผลรวม probe: ผ่าน 2, ไม่ผ่าน 2, exit code 1 ยืนยันว่าการเปลี่ยน layout เพิ่มปัญหาที่ความสูง 480 โดยไม่ต้องเปลี่ยน theme หรือ backend

หมายเหตุ baseline: คัดลอกโครง rendering ก่อน redesign เฉพาะ subtree, ใช้รายการ 4 ประเภทเดิม, ปุ่มไม่มีการบันทึก และใช้ placeholder icon ขนาด 20 เท่าของเดิม ไม่ใช่การรันแอป commit เก่าทั้งแอป รอบแรก baseline ขาด Material ancestor ทำให้ผลใช้ไม่ได้ ได้แก้เฉพาะ test harness แล้วรันใหม่จนได้ผลตามตาราง

## ขอบเขตและข้อจำกัด

- ตรวจ diff ทั้ง 12 driver screens รวม callback, navigation, conditions และสูตรแสดงยอดเก็บลูกค้า ยังไม่พบหลักฐานการเปลี่ยนสูตรธุรกิจ
- ข้อสงสัย Dashboard header กินพื้นที่จอเตี้ย และยอดเงินถูก ellipsis ยังไม่ได้พิสูจน์ด้วย runtime จึงไม่จัดเป็น bug ยืนยัน
- Wallet แนวนอนสถานะไม่มีผู้ใช้ผ่าน probe; ยังไม่ครอบคลุมยอดเงินจริงและ transaction history
- สี panel เข้มบน brand ไม่ถือเป็นข้อผิดพลาดโดยลำพัง; missing onBrand เป็นข้อเสนอเรื่องชื่อ semantic token
- ไม่แก้ production code, ไม่ build, ไม่ commit, ไม่ลบไฟล์
- เก็บ probe ที่ตรวจพบปัญหาไว้ตามคำสั่ง main; การรัน full suite รอบถัดไปจะรวม test ที่ยังไม่ผ่านนี้ด้วย ชุด 229 tests ที่ main รายงานผ่านเป็นชุดก่อนเพิ่ม probe
