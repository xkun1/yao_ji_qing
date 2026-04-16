# 💊 药记清 (Yao Ji Qing)

**AI 智能药管家 - 拍一张医嘱，AI 替你记。**

让长辈不再为复杂的服药计划发愁，让子女不再担心父母漏服药物。

---

## ✨ 核心特性

- **📸 拍照智能识别**：利用 Google Gemini AI，直接拍照医嘱或药盒，自动提取药品名称、剂量及服用频次。
- **⏰ 金刚级闹钟提醒**：
  - **全场景闭环**：点击通知、划掉通知或 10 分钟无操作，均能精准停止马达震动。
  - **进程防杀**：即便 App 被从后台杀掉，系统级闹钟依然准时提醒。
  - **原生马达支持**：采用 Android 原生 `VibrationEffect` 提供的强力震动反馈。
- **🎨 极简美学 UI**：沉浸式状态栏设计，纯净无广告，适配 Material 3 规范。
- **📂 自动归档**：智能保存用药历史，随时查看。

---

## 🚀 快速开始

### 开发环境
- Flutter SDK: `>=2.18.0`
- Android: API 21+ (推荐 Android 12+)
- iOS: 12.0+

### 安装步骤
1. 克隆项目
   ```bash
   git clone https://github.com/kunge/yao_ji_qing.git
   ```
2. 安装依赖
   ```bash
   flutter pub get
   ```
3. 运行项目
   ```bash
   flutter run
   ```

---

## 🛠 华为/安卓手机关键设置 (必读)

为了确保 App 在被杀掉进程后依然能准时提醒，请务必在手机设置中开启以下权限：

1. **应用启动管理**：
   - 路径：`设置 -> 应用 -> 应用启动管理 -> 药记清`。
   - 操作：关闭“自动管理”，手动开启 **“允许自启动”、“允许关联启动”、“允许后台活动”**。
2. **电池优化**：
   - 路径：`设置 -> 应用 -> 权限 -> 特殊权限访问 -> 电池优化`。
   - 操作：将“药记清”设为 **“不允许”** (即不进行电池优化)。
3. **通知权限**：确保开启了 **“横幅”**、**“锁屏通知”** 及 **“响铃/震动”** 权限。

---

## 🛡 技术栈

- **Framework**: Flutter (Dart)
- **AI**: Google Generative AI (Gemini 1.5 Flash)
- **Database**: Isar (高性能嵌入式 NoSQL)
- **Notifications**: Flutter Local Notifications + Android Native MethodChannel
- **UI**: Lottie Animation + Cupertino Icons

---

## 📝 开源协议
MIT License. 
Designed by **坤哥** with ❤️.
