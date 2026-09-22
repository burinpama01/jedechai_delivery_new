# JDC Delivery — AI Merchant Quick Setup Plan

**Version:** 0.1  
**Status:** Draft  
**Date:** 2026-09-19

---

# 1. เป้าหมาย

สร้างระบบ **AI Merchant Quick Setup** เพื่อช่วยให้ร้านค้าเปิดร้านบน JDC Delivery ได้เร็วที่สุด โดยลดงานที่ต้องกรอกด้วยมือ

แนวคิดหลัก:

> **“มีแค่รูปเมนู ก็เปิดร้านบน JDC ได้”**

AI จะช่วยอ่านข้อความจากเมนู รูปภาพ หรือเอกสาร แล้วแปลงเป็นข้อมูลร้านและเมนูแบบ Structured Data ให้ร้านตรวจสอบก่อน Publish

เป้าหมายเชิงธุรกิจ:

- ลดเวลา onboarding ร้านใหม่
- ลด friction ตอนสมัครร้าน
- ลดงานของทีม Admin
- ทำให้เซลส์สามารถ onboard ร้านหน้างานได้ทันที
- เพิ่มจำนวนร้านบนแพลตฟอร์มได้เร็วขึ้น
- ใช้ AI เป็น Merchant Acquisition Feature ไม่ใช่เพียง chatbot

---

# 2. Merchant Onboarding Flow

Flow หลัก:

```text
สมัครร้าน
   ↓
กรอกข้อมูลพื้นฐาน
   ↓
ปักหมุดร้าน
   ↓
AI Quick Setup
   ↓
ถ่ายรูป / Upload เมนู
   ↓
AI Extract
   ↓
Menu Draft
   ↓
Merchant Review
   ↓
AI ช่วยเติมข้อมูลที่ขาด
   ↓
Preview Store
   ↓
Publish
```

เป้าหมาย UX:

```text
สมัครร้าน → ถ่ายรูปเมนู → ตรวจสอบ → เปิดร้าน
```

---

# 3. Entry Point

หลัง Merchant สมัครสำเร็จ ให้แสดงหน้า:

```text
ตั้งค่าร้านแบบรวดเร็วด้วย AI

[ 📷 ถ่ายรูปเมนู ]
[ 🖼 อัปโหลดรูป ]
[ 📄 อัปโหลด PDF ]
[ 📊 อัปโหลด Excel / CSV ]
[ ✍️ กรอกเอง ]
```

ในอนาคต:

```text
[ เชื่อม StoreOS ]
[ นำเข้าจากระบบเดิม ]
[ Facebook / Google / POS Integration ]
```

---

# 4. AI Menu Import

## 4.1 Input ที่รองรับใน Version แรก

รองรับ:

```text
Camera Image
Gallery Image
Multiple Images
PDF
```

Version ถัดไป:

```text
Excel
CSV
StoreOS
External POS
```

---

# 5. Multi-image Import

ร้านสามารถถ่ายเมนูหลายหน้า

ตัวอย่าง:

```text
Image 1
กาแฟ

Image 2
ชา / เครื่องดื่ม

Image 3
อาหาร

Image 4
ของหวาน
```

UI:

```text
เมนูที่อัปโหลด

[Image 1]
[Image 2]
[Image 3]
[Image 4]

[ + เพิ่มรูป ]

[ วิเคราะห์ด้วย AI ]
```

AI ต้องสามารถ:

- รวมข้อมูลจากหลายภาพ
- ตรวจรายการซ้ำ
- แยกหมวดหมู่
- อ่านราคา
- อ่านตัวเลือก
- จัดลำดับเมนู

---

# 6. AI Extraction

AI ต้องดึงข้อมูลจากภาพเป็น Structured Data

ข้อมูลหลัก:

```text
category
name
description
price
options
variants
availability
confidence
source_image
```

ตัวอย่าง:

```json
{
  "category": "กาแฟ",
  "name": "Caramel Latte",
  "description": null,
  "price": 69,
  "options": [
    {
      "name": "ความหวาน",
      "choices": [
        {
          "label": "0%",
          "price_delta": 0
        },
        {
          "label": "25%",
          "price_delta": 0
        },
        {
          "label": "50%",
          "price_delta": 0
        },
        {
          "label": "100%",
          "price_delta": 0
        }
      ]
    }
  ],
  "confidence": 0.97
}
```

---

# 7. Menu Variant Detection

AI ต้องพยายามแยกว่าเมนูเดียวกันมี Variant หรือเป็นคนละเมนู

ตัวอย่างบนเมนู:

```text
ชาเขียว

เย็น 55
ปั่น 65
```

ระบบควรเสนอ:

```text
ชาเขียว
Base Price: 55

รูปแบบ

เย็น       +0
ปั่น       +10
```

แทนการสร้าง:

```text
ชาเขียวเย็น
ชาเขียวปั่น
```

โดยร้านสามารถเลือกเปลี่ยนได้ก่อน Publish

---

# 8. Option Detection

ตัวอย่าง:

```text
Latte

Hot 50
Cold 60
Frappe 70
```

AI แปลงเป็น:

```text
Latte

Base Price
50

Option: รูปแบบ

Hot       +0
Cold      +10
Frappe    +20
```

ถ้าในภาพมี:

```text
เพิ่ม Shot +15
เพิ่ม Syrup +10
```

AI สามารถสร้าง modifier group:

```text
Add-ons

Extra Shot     +15
Syrup          +10
```

---

# 9. Duplicate Detection

เมื่อร้านถ่ายหลายภาพ อาจมีเมนูซ้ำ

ตัวอย่าง:

```text
Image 1
Americano 50

Image 2
Americano 50
```

AI ต้อง merge เป็นรายการเดียว

หากข้อมูลไม่ตรงกัน:

```text
Image 1
Americano 50

Image 2
Americano 55
```

ให้ระบบแจ้ง:

```text
⚠️ พบข้อมูลราคาไม่ตรงกัน

Americano

50 บาท
หรือ
55 บาท

กรุณาเลือก
```

ห้าม AI เลือกเอง

---

# 10. Confidence Score

AI Extraction ทุก field สำคัญควรมี Confidence

ตัวอย่าง:

```text
Americano
50 บาท

Confidence
98%
```

ถ้า confidence ต่ำ:

```text
กาแฟส้ม

AI อ่านราคา:
69 บาท

Confidence:
61%

⚠️ กรุณาตรวจสอบ
```

กฎ:

```text
>= 90%
Normal

70–89%
Review Recommended

< 70%
Required Review
```

ราคาควรมี threshold เข้มกว่าข้อมูล description

---

# 11. Draft-first Architecture

AI ห้ามเขียนลง Menu Production Table โดยตรง

Flow:

```text
AI Extraction
      ↓
Import Job
      ↓
Draft Items
      ↓
Merchant Review
      ↓
Approved
      ↓
Publish
      ↓
Production Menu
```

---

# 12. Database Design

## merchant_import_jobs

```text
id
merchant_id
source_type
status
ai_run_id
total_files
total_items
low_confidence_items
created_at
completed_at
published_at
```

Status:

```text
uploaded
processing
review_required
ready
published
failed
cancelled
```

---

## merchant_import_sources

```text
id
import_job_id
source_type
storage_path
original_filename
page_number
created_at
```

---

## merchant_import_items

```text
id
import_job_id
source_id
category
name
description
price
options_json
variants_json
confidence
confidence_json
status
source_reference
created_at
updated_at
```

Status:

```text
draft
approved
edited
rejected
published
```

---

# 13. Source Traceability

แต่ละ AI Extracted Item ควรย้อนกลับไปยังต้นทางได้

ตัวอย่าง:

```text
Caramel Latte
69 บาท

Source:
menu-page-2.jpg

Region:
x: 180
y: 340
w: 420
h: 120
```

เพื่อให้ Merchant กดดูได้ว่า AI อ่านมาจากส่วนไหน

ช่วยตรวจสอบกรณี:

- ราคาอ่านผิด
- ชื่อไม่ชัด
- ตัวเลือกซับซ้อน
- มีรายการซ้ำ

---

# 14. Review Screen

หลัง AI วิเคราะห์เสร็จ:

```text
พบเมนู 32 รายการ

✓ พร้อมนำเข้า     25
⚠️ ต้องตรวจสอบ    5
❌ อ่านไม่ได้       2
```

Filter:

```text
ทั้งหมด
ต้องตรวจสอบ
พร้อมนำเข้า
ถูกแก้ไข
ไม่ใช้
```

ตัวอย่าง Card:

```text
Americano

ราคา
50 บาท

หมวด
กาแฟ

Confidence
98%

[แก้ไข]
[ไม่ใช้]
```

---

# 15. Bulk Review

ร้านไม่ควรต้องกดทีละรายการทั้งหมด

รองรับ:

```text
[เลือกทั้งหมด]

[อนุมัติรายการ Confidence สูง]
```

เช่น:

```text
อนุมัติรายการที่ Confidence >= 90%

25 รายการ
```

รายการต่ำกว่า threshold ต้องตรวจเอง

---

# 16. AI Category Detection

AI จัดหมวดให้อัตโนมัติ

ตัวอย่าง:

```text
กาแฟ
ชา
เครื่องดื่ม
อาหารจานเดียว
ของหวาน
Snack
```

ถ้า JDC มี Category เดิมของร้าน ให้ match กับ Category ที่มีอยู่ก่อน

เช่น:

```text
AI:
Coffee

Existing Category:
กาแฟ

→ Match
```

---

# 17. AI Description Generation

หากเมนูไม่มี Description ร้านสามารถเลือก:

```text
[✨ สร้างคำอธิบายด้วย AI]
```

ตัวอย่าง:

```text
Americano
```

กลายเป็น:

```text
กาแฟอเมริกาโน่รสเข้ม หอมกาแฟ ดื่มง่าย
```

แต่ต้องเป็น Optional Feature

AI ห้ามเพิ่มข้อมูลที่เป็นข้อเท็จจริงโดยไม่มีข้อมูลรองรับ เช่น:

```text
100% Arabica
Organic
Sugar Free
Premium Imported
```

หากไม่ได้ระบุในเมนูหรือข้อมูลร้าน

---

# 18. AI Store Setup Wizard

หลัง Menu Import เสร็จ AI ตรวจสอบว่าร้านยังขาดข้อมูลอะไร

ตัวอย่าง:

```text
AI Setup Status

✓ ชื่อร้าน
✓ เบอร์โทร
✓ ตำแหน่งร้าน
✓ เมนู 32 รายการ
✓ หมวดหมู่ 6 หมวด

ยังขาด

○ เวลาเปิด-ปิด
○ เวลาเตรียมอาหาร
○ รูปหน้าร้าน
○ Logo
○ รายละเอียดร้าน
```

---

# 19. Natural Language Store Setup

Merchant สามารถพิมพ์หรือพูด:

```text
เปิดทุกวัน 8 โมงถึง 2 ทุ่ม
หยุดวันพุธ
```

AI แปลงเป็น:

```json
{
  "monday": {
    "open": "08:00",
    "close": "20:00"
  },
  "tuesday": {
    "open": "08:00",
    "close": "20:00"
  },
  "wednesday": null,
  "thursday": {
    "open": "08:00",
    "close": "20:00"
  }
}
```

ก่อน Save ต้องแสดง Preview

---

# 20. Preparation Time Setup

AI สามารถถาม:

```text
ปกติร้านใช้เวลาเตรียมอาหารประมาณกี่นาที?
```

ร้านตอบ:

```text
กาแฟประมาณ 5 นาที
อาหารประมาณ 15 นาที
```

AI แปลง:

```text
Drink
5 min

Food
15 min
```

ข้อมูลนี้สามารถใช้ต่อกับ ETA Model ในอนาคต

---

# 21. Logo / Store Image Detection

หาก Merchant Upload ภาพเมนูหรือหน้าร้าน

AI สามารถเสนอ:

```text
พบ Logo ในภาพ

[ดูตัวอย่าง]

[ใช้เป็น Logo ร้าน]
[ไม่ใช้]
```

ห้ามตั้งเป็น Logo อัตโนมัติโดยไม่ให้ร้านตรวจสอบ

---

# 22. Architecture

แนะนำ:

```text
Merchant App
      │
      │ Upload
      ▼
Supabase Storage
      │
      ▼
merchant-ai-menu-import
      │
      ▼
Vision AI
      │
      ▼
Structured JSON
      │
      ▼
Import Draft Tables
      │
      ▼
Merchant Review
      │
      ▼
Publish Service
      │
      ▼
Menu Tables
```

---

# 23. Edge Functions

Version แรก:

```text
merchant-ai-menu-import
```

หน้าที่:

- validate Merchant
- validate upload
- create import job
- call AI Vision
- validate JSON
- create draft items
- calculate confidence
- detect duplicate
- return import summary

---

## Optional Functions

ภายหลังแยกเป็น:

```text
merchant-ai-menu-import
merchant-ai-store-setup
merchant-ai-description
merchant-ai-category
merchant-ai-logo-detect
merchant-ai-import-publish
```

หรือ route ทั้งหมดผ่าน:

```text
ai-gateway
```

โดยใช้:

```text
feature = merchant_menu_import
feature = merchant_setup
feature = merchant_description
```

---

# 24. AI Output Schema

AI ต้องตอบ JSON เท่านั้นในงาน extraction

ตัวอย่าง:

```json
{
  "categories": [
    {
      "name": "กาแฟ",
      "items": [
        {
          "name": "Americano",
          "description": null,
          "base_price": 50,
          "variants": [],
          "options": [],
          "confidence": {
            "name": 0.99,
            "price": 0.97,
            "category": 0.94
          }
        }
      ]
    }
  ]
}
```

Server ต้อง validate schema ก่อน Save

---

# 25. Security

Flutter ห้ามมี AI Provider Secret

Flow ต้องเป็น:

```text
Flutter
   ↓
Authenticated Supabase Request
   ↓
Edge Function
   ↓
AI Provider
```

Edge Function ต้องตรวจ:

```text
JWT
Merchant Role
Merchant ID ownership
Upload Ownership
Rate Limit
File Type
File Size
```

Client ห้ามส่ง:

```text
merchant_id
```

แล้วให้ server เชื่อตามนั้นโดยตรง

Server ควร derive merchant จาก authenticated user

---

# 26. File Upload Rules

แนะนำ Version แรก:

```text
JPEG
PNG
WebP
PDF
```

กำหนด:

```text
Max Images / Import
10

Max Image Size
10 MB

Max PDF Pages
20
```

ค่าจริงปรับได้ภายหลังตาม Cost และ AI Provider

---

# 27. AI Cost Control

เก็บทุกครั้งใน:

```text
ai_runs
```

ข้อมูล:

```text
feature
provider
model
input_tokens
output_tokens
estimated_cost
latency
merchant_id
import_job_id
```

ควรมี limit เช่น:

```text
Free AI Imports / Merchant
3
```

หรือ:

```text
AI Import Credit
```

เพื่อควบคุม abuse และต้นทุน

---

# 28. Image Optimization

ก่อนส่งภาพเข้า Vision AI:

```text
Original Image
      ↓
Auto Rotate
      ↓
Resize
      ↓
Compress
      ↓
AI Vision
```

ไม่ควรส่งภาพกล้องขนาดใหญ่มากโดยไม่จำเป็น

ช่วย:

- ลด upload time
- ลด AI cost
- ลด latency
- ลด storage

---

# 29. Error Handling

กรณี AI อ่านไม่ได้:

```text
ไม่สามารถอ่านเมนูบางส่วนได้
```

ให้ Merchant:

```text
[ถ่ายใหม่]
[อัปโหลดใหม่]
[กรอกเอง]
```

อย่าบังคับ Retry AI อย่างเดียว

---

# 30. Version 1 Scope

เป้าหมาย MVP:

```text
Merchant
   ↓
Upload Image / PDF
   ↓
AI Extract
   ↓
Name
Price
Category
Variant
Options
   ↓
Confidence Check
   ↓
Merchant Review
   ↓
Publish
```

สิ่งที่ยังไม่ต้องทำใน V1:

```text
Facebook Import
Grab Import
LINE MAN Import
Google Maps Import
Auto Logo Generation
Demand Prediction
Automatic Promotion
Complex POS Migration
```

---

# 31. Version 1.1

เพิ่ม:

```text
Opening Hours AI Setup
Preparation Time
Store Description Generation
Logo Extraction
Category Improvement
Bulk Approval
```

---

# 32. Version 1.2

เพิ่ม:

```text
Excel / CSV Import
StoreOS Import
Existing POS Import
Menu Optimization
AI Menu Description
Duplicate Resolution
Import History
```

---

# 33. Version 2 — Merchant Onboarding Agent

สร้าง AI Agent ที่คุยกับ Merchant ได้

ตัวอย่าง Merchant:

```text
ร้านผมขายกาแฟกับอาหารตามสั่ง
เปิด 8 โมงถึง 2 ทุ่ม
นี่รูปเมนู
```

AI:

```text
ตั้งค่าร้านให้เบื้องต้นแล้ว

ประเภทร้าน
Cafe / Restaurant

เวลาทำการ
08:00–20:00

พบเมนู
32 รายการ

หมวดหมู่
6 หมวด

มี 3 รายการที่ผมไม่แน่ใจเรื่องราคา
กรุณาตรวจสอบก่อนเปิดร้าน
```

เป้าหมายคือทำให้การเปิดร้านเหมือนคุยกับผู้ช่วยหนึ่งคน

---

# 34. Admin-assisted Onboarding

ควรรองรับกรณีทีม JDC ไปหาลูกค้าหน้างาน

Admin สามารถ:

```text
Create Merchant Draft
      ↓
Take Menu Photos
      ↓
AI Import
      ↓
Merchant Review
      ↓
Activate Merchant
```

ช่วยให้ทีม Sales สามารถพูดกับร้านได้ว่า:

> ส่งรูปเมนูให้เรา เดี๋ยวระบบช่วยลงร้านให้

---

# 35. Merchant Acquisition Strategy

Feature นี้สามารถใช้เป็น Selling Point โดยตรง

ข้อความหลัก:

> **มีแค่รูปเมนู ก็เปิดร้านบน JDC ได้**

ข้อความรอง:

```text
ไม่ต้องนั่งกรอกเมนูทีละรายการ

ถ่ายรูปเมนู
AI ช่วยอ่าน
ตรวจสอบ
เปิดร้านได้เลย
```

เหมาะกับ:

- ร้านอาหารเล็ก
- ร้านกาแฟ
- ร้านตามสั่ง
- ร้านที่ไม่มีทีมไอที
- ร้านที่ยังใช้เมนูกระดาษ
- ร้านที่มีเมนูอยู่แล้วแต่ไม่อยากกรอกใหม่

---

# 36. Success Metrics

ควรวัด:

```text
Merchant Signup → Setup Started
Setup Started → Menu Imported
Menu Imported → Published
Average Setup Time
AI Import Success Rate
Manual Correction Rate
Low Confidence Rate
Merchant Drop-off Rate
Cost per Merchant Onboarding
```

เป้าหมายสำคัญ:

```text
Time to First Published Menu
```

ยิ่งสั้นยิ่งดี

---

# 37. AI Quality Metrics

วัด:

```text
Menu Name Accuracy
Price Accuracy
Category Accuracy
Option Accuracy
Duplicate Detection Accuracy
Merchant Edit Rate
Merchant Reject Rate
```

Price Accuracy ต้องให้ความสำคัญสูงที่สุด

---

# 38. Audit Log

ทุก action ต้องมี log:

```text
who
merchant
import_job
source
AI result
edited fields
approved items
rejected items
published items
timestamp
```

เพื่อย้อนตรวจได้หากมีปัญหา

---

# 39. Recommended Implementation Order

```text
1. Import Database Schema

2. Supabase Storage

3. merchant-ai-menu-import Edge Function

4. JSON Schema Validation

5. Merchant Import UI

6. Review / Edit UI

7. Publish Service

8. Confidence Highlight

9. Duplicate Detection

10. Multi-image Import

11. AI Setup Wizard

12. Analytics / Cost Monitoring
```

---

# 40. Definition of Done — MVP

AI Merchant Quick Setup V1 ถือว่าเสร็จเมื่อ:

- Merchant Upload รูปเมนูได้
- รองรับหลายภาพ
- AI อ่านชื่อเมนูได้
- AI อ่านราคาได้
- AI จัดหมวดหมู่ได้
- AI อ่าน Variant/Option พื้นฐานได้
- มี Confidence Score
- มี Draft Layer
- Merchant แก้ไขได้
- Merchant Reject รายการได้
- Merchant Approve หลายรายการได้
- Detect เมนูซ้ำพื้นฐานได้
- Publish เข้า Menu จริงได้
- มี AI Run Log
- มี Audit Log
- API Key ไม่อยู่ใน Flutter
- Merchant เห็น Preview ก่อน Publish

---

# 41. Long-term Direction

เป้าหมายสุดท้าย:

```text
Merchant Registration
        ↓
AI Onboarding
        ↓
AI Menu Setup
        ↓
AI Store Setup
        ↓
AI Operations
        ↓
AI Merchant Insights
```

จากเดิมที่ Merchant ต้องเรียนรู้ระบบก่อนถึงจะเปิดร้านได้

เปลี่ยนเป็น:

> Merchant ให้ข้อมูลเท่าที่มี แล้ว AI ช่วยแปลงข้อมูลนั้นให้กลายเป็นร้านที่พร้อมขายบน JDC Delivery

นี่ควรเป็นหนึ่งใน Feature หลักของการขยาย Merchant Network ของ JDC Delivery
