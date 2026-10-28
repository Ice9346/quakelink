# QuakeLink

โปรเจกต์ระบบติดตามแผ่นดินไหว ประกอบด้วย Flutter Web, Node.js backend, PostgreSQL และ ThingsBoard

## ติดตั้งครั้งแรกบน macOS

เปิด Terminal แล้วติดตั้งเครื่องมือที่ต้องใช้เป็นเวอร์ชันล่าสุด:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install git node
brew install --cask flutter
brew install --cask docker
```

เปิด Docker Desktop ให้ทำงานก่อนเริ่มขั้นตอนถัดไป ถ้ามี Homebrew อยู่แล้ว ให้ข้ามคำสั่งติดตั้ง Homebrew ได้เลย

## ติดตั้งบน Windows

ติดตั้งโปรแกรมล่าสุดจากเว็บไซต์ทางการ:

- [Git for Windows](https://git-scm.com/download/win)
- [Flutter SDK](https://docs.flutter.dev/install/manual)
- [Node.js](https://nodejs.org/en/download)
- [Docker Desktop](https://docs.docker.com/desktop/setup/install/windows-install/)

หลังติดตั้ง Flutter ให้เพิ่มโฟลเดอร์ `flutter\bin` ลงใน Windows `Path` แล้วเปิด Terminal ใหม่

แนะนำให้ใช้ **Git Bash** หรือ **WSL** ใน VS Code เพราะคำสั่งของโปรเจกต์ใช้ Bash script จากนั้นทำตามขั้นตอนเดียวกับ macOS ตั้งแต่หัวข้อดาวน์โหลดโปรเจกต์เป็นต้นไป

## ดาวน์โหลดโปรเจกต์

```bash
git clone https://github.com/Ice9346/quakelink.git
cd quakelink
```

## เตรียมไฟล์ตั้งค่า

นำไฟล์ `.env` ที่ได้รับมาวางที่:

```text
server/.env
```

ไม่ต้องสร้างหรือค้นหา API key เพิ่มเอง ไฟล์ `.env` มีค่าที่ใช้เชื่อมต่อระบบอยู่แล้ว

ห้ามอัปโหลดไฟล์นี้ขึ้น GitHub เพราะมีรหัสผ่านและ token โดยโปรเจกต์ตั้งค่า Git ignore ไว้แล้ว

## เปิดฐานข้อมูลและติดตั้ง backend

เปิด Docker Desktop ก่อน แล้วเปิด Terminal จากโฟลเดอร์โปรเจกต์:

```bash
cd server
docker compose up -d
npm install
npm run prisma:generate
npm run prisma:migrate
```

## รัน backend

เปิด Terminal หนึ่งหน้าต่างค้างไว้:

```bash
cd /path/to/quakelink/server
npm run dev
```

เมื่อสำเร็จ backend จะทำงานที่ `http://127.0.0.1:8080`

## รันหน้าเว็บ

เปิด Terminal อีกหน้าต่าง:

```bash
cd /path/to/quakelink
flutter pub get
bash tool/run_local_web.sh
```

เปิดเว็บที่:

```text
http://127.0.0.1:5173
```

อย่าเปิดไฟล์ `web/index.html` ด้วย `file://` โดยตรง ต้องเปิดผ่าน Flutter Web server เท่านั้น

## การจำลองข้อมูล sensor

ถ้าไฟล์ `.env` เปิด simulator ไว้ ระบบจะส่งข้อมูลจำลองเข้า ThingsBoard ทันทีเมื่อ backend เริ่มทำงาน และส่งซ้ำทุก 5 นาที

ถ้าเปิด Spacebar simulator ไว้ สามารถกด Spacebar ใน Terminal เดียวกับ `npm run dev` เพื่อส่งข้อมูลทันที

## ตรวจสอบระบบ

```bash
flutter test
flutter analyze
cd server
npm run check
```
